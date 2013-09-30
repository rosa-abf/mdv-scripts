#!/usr/bin/python
#
# build-changelog - Output a rpm changelog
#
# Copyright (C) 2009-2010  Red Hat, Inc.
# Copyright (C) 2013 Robert Xu
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: David Cantrell <dcantrell@redhat.com>
# Author: Brian C. Lane <bcl@redhat.com>
# Author: Robert Xu <robxu9@gmail.com>

import os
import re
import subprocess
import sys
import textwrap
import datetime
from optparse import OptionParser



class ChangeLog:
    def __init__(self, options):
        self.options = options
        self.ignore = None
    
    def _getEVR(self, name, commit):
        pop = subprocess.Popen('set -e; TMPFILE=$(mktemp /tmp/output.XXXXXXXXXX); git show %s:%s > $TMPFILE; rpm --specfile $TMPFILE -q --queryformat \'%%{epoch}:%%{version}-%%{release}\' 2>/dev/null | tail -n1; rm -rf $TMPFILE' % (commit, name),
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, shell=True)
        proc = pop.communicate()
        if pop.returncode != 0:
            return None
        
        return proc[0].strip('\n')
        

    def _getCommitDetail(self, commit, field):
        proc = subprocess.Popen('git log -1 --pretty=format:%s %s' % (field, commit),
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, shell=True).communicate()

        ret = proc[0].strip('\n').split('\n')

#        if len(ret) == 1 and ret[0].find('@') != -1:
#            ret = ret[0].split('@')[0]
#        elif len(ret) == 1:
#            ret = ret[0]
#        else:
#            ret = filter(lambda x: x != '', ret)
        if len(ret) == 1:
             ret = ret[0]

        return ret

    def getLog(self):
        if self.options.bk is not None:
            tree = "%s~%s..%s" % (self.options.head, int(self.options.bk) + 25, self.options.head)
        elif self.options.tag is not None:
            tree = "%s..%s" % (self.options.tag, self.options.head)
        elif self.options.fr is not None:
            tree = "%s..%s" % (self.options.fr, self.options.head)
        else:
            tree = self.options.head
        proc = subprocess.Popen(['git', 'log', '--pretty=oneline', tree],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE).communicate()
        lines = filter(lambda x: x.find('l10n: ') != 41 and \
                                 x.find('Merge commit') != 41 and \
                                 x.find('Merge branch') != 41 and \
                                 x.find('Merge pull request') != 41 and \
                                 x.find('SILENT: ') != 41,
                       proc[0].strip('\n').split('\n'))

        if self.ignore and self.ignore != '':
            for commit in self.ignore.split(','):
                lines = filter(lambda x: not x.startswith(commit), lines)

        goodcommits = 0
        log = []
        for line in lines:
            goodcommits += 1
            fields = line.split(' ')
            commit = fields[0]
            
            if self.options.name is not None:
                evr = self._getEVR(self.options.name, commit)
            else:
                evr = ""

            body = self._getCommitDetail(commit, "%B")
            hash = self._getCommitDetail(commit, "%h")
            author = self._getCommitDetail(commit, "%aN")
            email = self._getCommitDetail(commit, "%aE")
            date = self._getCommitDetail(commit, "%ct")

            log.append(("* %s %s <%s> %s" % (datetime.datetime.fromtimestamp(int(date)).strftime('%a %b %d %Y'), author, email, evr)))
            log.append(("+ Revision: %s" % hash))
            if isinstance(body, (list, tuple)):
                for bodyline in body:
                    if bodyline.strip():
                        log.append(("- %s" % bodyline.strip()))
            else:
                log.append(("- %s" % body.strip()))
            log.append("")

            if goodcommits is self.options.bk:
                break


        return log

    def formatLog(self):
        s = ""
        for msg in self.getLog():
             s = s + "%s\n" % msg
#            sublines = textwrap.wrap(msg, 77)
#            s = s + "- %s\n" % sublines[0]
#
#            if len(sublines) > 1:
#                for subline in sublines[1:]:
#                    s = s + "  %s\n" % subline

        return s

def main():
    parser = OptionParser()
    parser.add_option("-t", "--tag", dest="tag",
                      help="Last tag, changelog is commits after this tag [overrides --from and --back]")
    parser.add_option("-f", "--from", dest="fr",
                      help="From this commit onwards [overrides --tag and --back]")
    parser.add_option("-b", "--back", dest="bk",
                      help="Back x number of commits from the topmost commit [overrides --from and --tag]")
    parser.add_option("-e", "--head", dest="head",
                      help="Specify the topmost commit (default HEAD)")
    parser.add_option("-n", "--name", dest="name",
                      help="Specify a name of a spec file to parse (allows for EVR in changelog)")
    (options, args) = parser.parse_args()

    if options.head is None:
        options.head = "HEAD"

    cl = ChangeLog(options)
    print cl.formatLog()

if __name__ == "__main__":
    main()


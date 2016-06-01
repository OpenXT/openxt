#!/usr/bin/env python

# Copyright (c) 2016 Assured Information Security, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

import SimpleXMLRPCServer
import os
import subprocess
import socket
import sys
import getopt
import shutil
import ConfigParser
import tempfile
import logging
import sys

linesep = '\n'
SCRIPTDIR = os.path.dirname(os.path.realpath(sys.argv[0]))

def onerror(func, path, exc_info):
    """
    Error handler for ``shutil.rmtree``.

    If the error is due to an access error (read only file)
    it attempts to add write permission and then retries.

    If the error is for another reason it re-raises the error.

    Usage : ``shutil.rmtree(path, onerror=onerror)``
    """
    import stat
    print "Retrying " + path + " after chmod"
    os.chmod(path, stat.S_IWRITE)
    func(path)

def runCommand(command):
    s = subprocess.Popen(command, shell = True,
                      stdout = subprocess.PIPE, stderr = subprocess.STDOUT,
                      universal_newlines=True)
    while True:
        output = s.stdout.readline()
        if output == '' and s.poll() is not None:
            break
        if output:
            logging.info(output.strip())
    ret = s.poll()
    return ret

class RPCInterface(object):
    def make(self,build='',branch='master',certname='',developer='false',rsyncdest='',giturl='',config='sample-config.xml'):
        """make(build,branch,certname,developer,rsyncdest,giturl,config)
           Ex: make("123456","master","developer","false","builds@192.168.0.10:/home/builds/win/","git://github.com/OpenXT","sample-config.xml")
           Call powershell scripts to do the real work
        """

        result = 'SUCCESS'

        if not os.path.exists(BUILDDIR):
            os.mkdir(BUILDDIR)
        os.chdir(BUILDDIR)

        if os.path.exists('output.log'):
            os.remove('output.log')
        logging.basicConfig(filename='output.log', level=logging.DEBUG)
        log = logging.getLogger()
        print "Log file created @ " + socket.gethostname() + " file: " + os.path.join(BUILDDIR, "output.log")

        # Create log directory/file
        try:
            logging.info("Start build, RPC input:")
            logging.info('make(build='+repr(build)+',branch='+repr(branch)+\
                  ',certname='+repr(certname)+'developer='+repr(developer)+\
                  'rsyncdest='+repr(rsyncdest)+'giturl='+repr(giturl)+'config='+repr(config)+')')
            logging.info('Running in dir: ' + os.getcwd())

            # Nuke existing build(s)
            if not os.path.exists('garbage'):
                os.mkdir('garbage')
            if os.path.exists('openxt'):
                grave = tempfile.mkdtemp(dir='garbage')
                os.rename('openxt', os.path.join(grave, 'openxt'))
            try:
                shutil.rmtree('garbage', onerror=onerror)
            except:
                pass

            # Clone the main OpenXT repo and checkout branch
            runCommand('git clone -b ' + branch + ' ' + giturl + '/openxt.git')
            logging.info("Completed cloning " + giturl + "/openxt.git")
            os.chdir(os.path.join("openxt", "windows"))

            command = 'sed -i "s/Put Your Company Name Here/OpenXT/g" config\\sample-config.xml'
            runCommand(command)

            logging.info("Building Windows bits...")
            command = 'powershell .\winbuild-prepare.ps1 config=' + config + ' build=' + build + ' branch=' + branch + ' certname=' + certname + ' developer=' + developer
            runCommand(command)
            command = 'powershell .\winbuild-all.ps1'
            runCommand(command)

            # rsync the output unless something went wrong
            os.chdir(os.path.join(BUILDDIR, "openxt", "windows", "output"))
            if os.path.exists('xctools-iso.zip') and os.path.exists('xc-wintools.iso'):
                # Save build ID
                build_id_file = open('BUILD_ID', 'w')
                build_id_file.write(str(build))
                build_id_file.write('\n')
                build_id_file.close()
                # Rsync the build output to the builder
                command = "rsync --rsh='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i " \
                          + os.path.join(SCRIPTDIR, "id_rsa") \
                          + "' --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r -a * " \
                          + rsyncdest
                child_error = runCommand(command)
                if child_error != 0:
                    # Misery
                    logging.error("ERROR: OpenXT Tools failed to rsync!")
                    result = 'FAILURE'
            else:
                # Misery
                logging.error("ERROR: OpenXT Tools failed to build!")
                result = 'FAILURE'
        finally:
            if log is not None:
                handlers = log.handlers[:]
                for handler in handlers:
                    handler.close()
                    log.removeHandler(handler)

        return result

    def hello(self):
        return "hello back"

    def get_ssh_public_key(self):
        certfile = open(os.path.join(SCRIPTDIR, "id_rsa.pub"))
        cert = certfile.readline()
        certfile.close()
        return cert.strip()

def main(argv):

	config = ""
	site = ""
	try:
		opts, args = getopt.getopt(argv, "hc:s:", ["help", "config=", "site="])
		for opt, arg in opts:
			if opt in ("-h", "--help"):
				usage()
				sys.exit()
			elif opt in ("-c", "--config"):
				config = arg
			elif opt in ("-s", "--site"):
				site = arg
	except getopt.GetoptError:
		usage()
		sys.exit(2)

	loadConfig(config,site)
	s = SimpleXMLRPCServer.SimpleXMLRPCServer(('', PORT))
	s.register_introspection_functions()
	s.register_instance(RPCInterface())

	try:
		print """
		 OpenXT Windows Build XMLRPC Server

		 Use Control-C to exit
		 """
		s.serve_forever()
	except KeyboardInterrupt:
		print 'Exiting'

def loadConfig(cfg,site):
	try:
		config = ConfigParser.ConfigParser()
		config.read(cfg)
	except:
		print "Configuration file cannot be read."
		sys.exit()

	if not (config.has_section(site)):
		print "Invalid site specified. Available sites are:"
		print config.sections()
		sys.exit()
	else:
		try:
			global PORT, BUILDDIR
			PORT = config.getint(site,'port')
			BUILDDIR = config.get(site,'builddir')
		except:
			print "Exception getting configuration option. Corrupt .cfg file? Missing option?"
			sys.exit()

def usage():
	print """
	 Usage:
	 > python builddaemon.py -c "config file" -s "site"
	"""

if __name__ == '__main__':
	main(sys.argv[1:])

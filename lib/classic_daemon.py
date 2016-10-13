#!/usr/bin/env python3
# -*- coding: utf-8 -*-
__author__ = "Evgeny Markov"

import sys
import os
import time
import atexit
from signal import SIGTERM
from ctypes import cdll, byref, create_string_buffer


def set_process_name(proc_name):
	# Set process name
	libc = cdll.LoadLibrary("libc.so.6")
	buff = create_string_buffer(len(proc_name)+1)
	buff.value = bytes(proc_name, encoding="utf-8")
	libc.prctl(15, byref(buff), 0, 0, 0)


class Daemon:
	"""
	Parent class for work with daemon.
	You need to override run method
	"""

	def __init__(self, pidfile, proc_name, stdin='/dev/null', stdout='/dev/null', stderr='/dev/null'):
		self.stdin = stdin
		self.stdout = stdout
		self.stderr = stderr
		self.pidfile = pidfile
		self.proc_name = proc_name

		set_process_name(self.proc_name)

	def daemonize(self):
		"""
		ƒвойной форк UNIX:
		ƒл¤ того чтобы просто перевести себ¤ в фоновой режим вашему скрипту более чем достаточно
		сделать один раз fork и выйти из родительского процесса, двойной форк нужен он в том случае
		если вы делаете fork в каком-либо долгоиграющем процессе иначе получаютс¤ "процессы-зомби".
		«омби - это дочерние процессы, которые завершили своЄ выполнение и теперь ждут когда же они
		наконец смогут вернуть свой статус родителю или будут автоматически закрыты при его завершении.
		"""
		try:
			pid = os.fork()
			if pid > 0:
				# Exit from first
				sys.exit(0)
		except OSError as e:
			sys.stderr.write("fork #1 failed: %d (%s)\n" % (e.errno, e.strerror))
			sys.exit(1)
		# Detach from parent process environment
		os.setsid()
		os.umask(0)

		# Second fork
		try:
			pid = os.fork()
			if pid > 0:
				# Exit from second parent
				sys.exit(0)
		except OSError as e:
			sys.stderr.write("fork #2 failed: %d (%s)\n" % (e.errno, e.strerror))
			sys.exit(1)

		# Redirect standard file descriptors
		sys.stdout.flush()
		sys.stderr.flush()
		si = open(self.stdin, "r")
		so = open(self.stdout, "a+")
		se = open(self.stderr, "a+")
		os.dup2(si.fileno(), sys.stdin.fileno())
		os.dup2(so.fileno(), sys.stdout.fileno())
		os.dup2(se.fileno(), sys.stderr.fileno())

		# Write pidfile
		atexit.register(self.delpid)
		pid = str(os.getpid())
		pid_file = open(self.pidfile, "w+")
		pid_file.write("%s\n" % pid)
		pid_file.close()

	def delpid(self):
		"""
		Delete file with process-daemon identificator
		"""
		os.remove(self.pidfile)

	def start(self):
		"""
		Start the daemon
		"""
		# Check for a pidfile to see if the daemon already runs
		try:
			pf = open(self.pidfile, "r")
			pid = int(pf.read().strip())
			pf.close()
		except IOError:
			pid = None

		if pid:
			message = "pidfile %s already exist. Daemon already running?\n"
			sys.stderr.write(message % self.pidfile)
			sys.exit(1)

		# Start the daemon
		self.daemonize()
		self.run()

	def stop(self):
		"""
		Stop the daemon
		"""
		# Get the pid from the pidfile
		try:
			pf = open(self.pidfile, 'r')
			pid = int(pf.read().strip())
			pf.close()
		except IOError:
			pid = None

		if not pid:
			message = "pidfile %s does not exist. Daemon not running?\n"
			sys.stderr.write(message % self.pidfile)
			return  # not an error in a restart

		# Try killing the daemon process
		try:
			while 1:
				os.kill(pid, SIGTERM)
				time.sleep(0.1)
		except OSError as err:
			err = str(err)
			if err.find("No such process") > 0:
				if os.path.exists(self.pidfile):
					os.remove(self.pidfile)
			else:
				sys.exit(1)

	def restart(self):
		"""
		Restart the daemon
		"""
		self.stop()
		self.start()

	def run(self):
		"""
		You should override this method when you subclass Daemon.
		It will be called after the process has been daemonized by start() or restart().
		"""
		pass
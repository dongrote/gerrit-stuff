# -*- python -*-
# vim: set syntax=python
import os
import GerritLDAPServer
from twisted.internet import protocol
from twisted.python import components
from ldaptor import ldiftree, interfaces
from twisted.application import service, internet

db = ldiftree.LDIFTreeEntry('/tmp/ldapdb.tmp')

class GerritLDAPServerFactory(protocol.ServerFactory):
    protocol = GerritLDAPServer.GerritLDAPServer
    def __init__(self, root):
        self.root = root

GERRIT_LDAP_DEBUG = os.getenv('GERRIT_LDAP_DEBUG', default='0')
GerritLDAPServer.email_domain = os.getenv('EMAIL_DOMAIN', default='example.com')
GerritLDAPServer.GerritLDAPServer.debug = GERRIT_LDAP_DEBUG != '0'

components.registerAdapter(lambda x: x.root,
                            GerritLDAPServerFactory,
                            interfaces.IConnectedLDAPEntry)

application = service.Application("ldaptor-server")
myService = service.IServiceCollection(application)

factory = GerritLDAPServerFactory(db)

myServer = internet.TCPServer(38942, factory)
myServer.setServiceParent(myService)

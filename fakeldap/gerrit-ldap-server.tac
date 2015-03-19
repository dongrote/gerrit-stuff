# -*- python -*-
# vim: set syntax=python
from GerritLDAPServer import GerritLDAPServer
from twisted.internet import protocol
from twisted.python import components
from ldaptor import ldiftree, interfaces
from twisted.application import service, internet

db = ldiftree.LDIFTreeEntry('/tmp/ldapdb.tmp')

class GerritLDAPServerFactory(protocol.ServerFactory):
    protocol = GerritLDAPServer
    def __init__(self, root):
        self.root = root

GerritLDAPServer.debug = True

components.registerAdapter(lambda x: x.root,
                            GerritLDAPServerFactory,
                            interfaces.IConnectedLDAPEntry)

application = service.Application("ldaptor-server")
myService = service.IServiceCollection(application)

factory = GerritLDAPServerFactory(db)

myServer = internet.TCPServer(38942, factory)
myServer.setServiceParent(myService)

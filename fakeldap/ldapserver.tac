# -*- python -*-
# vim: set syntax=python
from SimpleLDAPServer import SimpleLDAPServer
from twisted.internet import protocol
from twisted.python import components
from ldaptor import ldiftree, interfaces
from twisted.application import service, internet

db = ldiftree.LDIFTreeEntry('/tmp/ldapdb.tmp')

class SimpleLDAPServerFactory(protocol.ServerFactory):
    protocol = SimpleLDAPServer
    def __init__(self, root):
        self.root = root

SimpleLDAPServer.debug = True

components.registerAdapter(lambda x: x.root,
                            SimpleLDAPServerFactory,
                            interfaces.IConnectedLDAPEntry)

application = service.Application("ldaptor-server")
myService = service.IServiceCollection(application)

factory = SimpleLDAPServerFactory(db)

myServer = internet.TCPServer(38942, factory)
myServer.setServiceParent(myService)

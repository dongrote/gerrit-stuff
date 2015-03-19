import pam
from ldaptor import interfaces, entry
from ldaptor.protocols import pureldap
from ldaptor.protocols.ldap import distinguishedname, ldaperrors
from ldaptor.protocols.ldap.ldapserver import LDAPServer

email_domain='example.com'

# sample /etc/passwd entry
#username:x:uid:gid:displayName,,,:/home/username:/bin/bash

def getUserEntryInEtcPasswd(username):
    passwdfile = open('/etc/passwd', 'r')
    for line in passwdfile:
        userEntry = line.split(':')
        if userEntry[0] == username:
            return userEntry
    raise ValueError('User not found: %r' % username)

def getUserAttribute_uid(username):
    #userEntry = getUserEntryInEtcPasswd(username)
    #return userEntry[2]
    return username

def getUserAttribute_gidNumber(username):
    userEntry = getUserEntryInEtcPasswd(username)
    return userEntry[3]

def getUserAttribute_mail(username):
    return '%s@%s' % (username, email_domain)

def getUserAttribute_username(username):
    return username

def getUserAttribute_displayName(username):
    userEntry = getUserEntryInEtcPasswd(username)
    return userEntry[4].split(',')[0]

def getUserAttribute(username,attribute):
    if (attribute == 'uid'):
        return getUserAttribute_uid(username)
    if (attribute == 'mail'):
        return getUserAttribute_mail(username)
    if (attribute == 'username'):
        return getUserAttribute_username(username)
    if (attribute == 'gidNumber'):
        return getUserAttribute_gidNumber(username)
    if (attribute == 'displayName'):
        return getUserAttribute_displayName(username)
    raise ValueError('Invalid attribute: %r' % attribute)

class SimpleLDAPServer(LDAPServer):
    def __init__(self):
        self.pam = pam.pam()
        LDAPServer.__init__(self)

    def handle_LDAPAddRequest(self, request, controls, reply):
        pass

    def handle_LDAPBindRequest(self, request, controls, reply):
        if request.version != 3:
            raise ldaperrors.LDAPProtocolError(
                'Version %u not supported' % request.version)
        self.checkControls(controls)
        if request.dn == '':
            # anonymous bind
            return pureldap.LDAPBindResponse(resultCode=0)
        else:
            if self.pam.authenticate(request.dn,request.auth):
                msg = pureldap.LDAPBindResponse(
                        resultCode=ldaperrors.Success.resultCode,
                        matchedDN=request.dn)
                return msg
            else:
                raise ldaperrors.LDAPInvalidCredentials

    def handle_LDAPUnbindRequest(self, request, controls, reply):
        return LDAPServer.handle_LDAPUnbindRequest(self, request, controls,
            reply)

    def handle_LDAPDelRequest(self, request, controls, reply):
        pass

    def handle_LDAPExtendedRequest(self, request, controls, reply):
        pass

    def handle_LDAPModifyDNRequest(self, request, controls, reply):
        pass

    def handle_LDAPModifyRequest(self, request, controls, reply):
        pass

    def handle_LDAPSearchRequest(self, request, controls, reply):
        print 'rx SearchRequest: %r' % request
        if (request.baseObject == ''
            and request.scope == pureldap.LDAP_SCOPE_baseObject
            and request.filter == pureldap.LDAPFilter_present('objectClass')):
            replyEntry = pureldap.LDAPSearchResultEntry(
                objectName='',
                attributes=[ ('supportedLDAPVersion', ['3']),
                             ('namingContexts', ['ou=people,dc=nodomain']),
                             ('supportedExtension', [])
                ]
                )
            print 'replyEntry: %r' % replyEntry
            reply(replyEntry)
            response = pureldap.LDAPSearchResultDone(
                    resultCode=ldaperrors.Success.resultCode)
            print 'response: %r' % response
            return response
        if ((request.baseObject == 'ou=people,dc=nodomain')
            and isinstance(request.filter,pureldap.LDAPFilter_equalityMatch)
            and (request.filter.attributeDesc.value == 'uid')):
            username=request.filter.assertionValue.value
            attributes=[]
            for attr in request.attributes:
                attributes.append((attr, [getUserAttribute(username,attr)]))
            response = pureldap.LDAPSearchResultEntry(
                    'dn=uid,ou=people,dc=nodomain',
                    attributes=attributes)
            reply(response)
            return pureldap.LDAPSearchResultDone(
                    resultCode=ldaperrors.Success.resultCode)
        if (request.baseObject == 'ou=groups,dc=nodomain'):
            response = pureldap.LDAPSearchResultEntry(
                    'dn=Users,out=groups,dc=nodomain',
                    attributes={})
            reply(response)
            return pureldap.LDAPSearchResultDone(
                    resultCode=ldaperrors.Success.resultCode)

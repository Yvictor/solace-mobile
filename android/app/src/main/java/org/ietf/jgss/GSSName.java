package org.ietf.jgss;

public interface GSSName {
    Oid NT_HOSTBASED_SERVICE = createHostBasedServiceOid();

    static Oid createHostBasedServiceOid() {
        try {
            return new Oid("1.2.840.113554.1.2.1.4");
        } catch (GSSException e) {
            throw new IllegalStateException(e);
        }
    }
}

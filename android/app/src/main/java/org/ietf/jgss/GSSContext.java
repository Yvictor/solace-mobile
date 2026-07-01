package org.ietf.jgss;

public interface GSSContext {
    int DEFAULT_LIFETIME = 0;

    void requestMutualAuth(boolean state) throws GSSException;

    void requestCredDeleg(boolean state) throws GSSException;

    byte[] initSecContext(byte[] inputBuf, int offset, int len) throws GSSException;

    boolean isEstablished();

    void dispose() throws GSSException;
}

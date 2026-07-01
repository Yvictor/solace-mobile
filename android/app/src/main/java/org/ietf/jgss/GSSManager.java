package org.ietf.jgss;

public abstract class GSSManager {
    public static GSSManager getInstance() {
        return new StubGSSManager();
    }

    public abstract GSSName createName(String nameStr, Oid nameType) throws GSSException;

    public abstract GSSContext createContext(
            GSSName peer,
            Oid mech,
            GSSCredential credential,
            int lifetime) throws GSSException;

    private static final class StubGSSManager extends GSSManager {
        @Override
        public GSSName createName(String nameStr, Oid nameType) {
            return new StubGSSName();
        }

        @Override
        public GSSContext createContext(GSSName peer, Oid mech, GSSCredential credential, int lifetime) {
            return new StubGSSContext();
        }
    }

    private static final class StubGSSName implements GSSName {
    }

    private static final class StubGSSContext implements GSSContext {
        @Override
        public void requestMutualAuth(boolean state) {
        }

        @Override
        public void requestCredDeleg(boolean state) {
        }

        @Override
        public byte[] initSecContext(byte[] inputBuf, int offset, int len) throws GSSException {
            throw new GSSException(GSSException.FAILURE);
        }

        @Override
        public boolean isEstablished() {
            return false;
        }

        @Override
        public void dispose() {
        }
    }
}

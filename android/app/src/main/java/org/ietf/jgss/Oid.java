package org.ietf.jgss;

public final class Oid {
    private final String value;

    public Oid(String value) throws GSSException {
        if (value == null || value.isEmpty()) {
            throw new GSSException(GSSException.FAILURE);
        }
        this.value = value;
    }

    @Override
    public String toString() {
        return value;
    }
}

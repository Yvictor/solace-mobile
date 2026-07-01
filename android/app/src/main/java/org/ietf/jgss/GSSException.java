package org.ietf.jgss;

public class GSSException extends Exception {
    public static final int FAILURE = 11;

    private final int major;

    public GSSException(int major) {
        super("GSS failure: " + major);
        this.major = major;
    }

    public int getMajor() {
        return major;
    }
}

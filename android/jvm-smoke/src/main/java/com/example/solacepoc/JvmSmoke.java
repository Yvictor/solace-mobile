package com.example.solacepoc;

public final class JvmSmoke {
    private JvmSmoke() {
    }

    public static void main(String[] args) throws Exception {
        String host = env("SOLACE_HOST", "");
        String vpn = env("SOLACE_VPN", "");
        String username = env("SOLACE_USER", "");
        String password = env("SOLACE_PASSWORD", "");
        String subscribeTopic = env("SOLACE_SUBSCRIBE_TOPIC", env("SOLACE_TOPIC", "android/poc"));
        String publishTopic = env("SOLACE_PUBLISH_TOPIC", subscribeTopic);
        int compression = Integer.parseInt(env("SOLACE_COMPRESSION_LEVEL", "3"));

        if (host.isEmpty() || vpn.isEmpty() || username.isEmpty()) {
            System.out.println("Classpath OK. Set SOLACE_HOST, SOLACE_VPN, SOLACE_USER, and SOLACE_PASSWORD to connect.");
            return;
        }

        SolaceProbe.Result result = SolaceProbe.run(
                new SolaceProbe.Config(host, vpn, username, password, subscribeTopic, publishTopic, compression));
        System.out.println(result.summary);
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value == null ? fallback : value;
    }
}

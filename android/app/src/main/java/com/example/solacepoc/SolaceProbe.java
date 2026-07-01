package com.example.solacepoc;

import com.solace.messaging.MessagingService;
import com.solace.messaging.config.AuthenticationStrategy;
import com.solace.messaging.config.SolaceProperties;
import com.solace.messaging.config.profile.ConfigurationProfile;
import com.solace.messaging.publisher.DirectMessagePublisher;
import com.solace.messaging.receiver.DirectMessageReceiver;
import com.solace.messaging.receiver.InboundMessage;
import com.solace.messaging.resources.Topic;
import com.solace.messaging.resources.TopicSubscription;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

public final class SolaceProbe {
    private SolaceProbe() {
    }

    public static Result run(Config config) throws Exception {
        validate(config);

        MessagingService service = null;
        DirectMessageReceiver receiver = null;
        DirectMessagePublisher publisher = null;

        try {
            service = MessagingService.builder(ConfigurationProfile.V1)
                    .fromProperties(config.toProperties())
                    .withAuthenticationStrategy(AuthenticationStrategy.BasicUserNamePassword.of(
                            config.username,
                            config.password))
                    .withMessageCompression(config.compressionLevel)
                    .build()
                    .connect();

            TopicSubscription subscription = TopicSubscription.of(config.subscribeTopic);
            receiver = service.createDirectMessageReceiverBuilder()
                    .withSubscriptions(subscription)
                    .build()
                    .start();

            String payload = "solace-mobile-android-" + UUID.randomUUID();
            if (!isBlank(config.publishTopic)) {
                publisher = service.createDirectMessagePublisherBuilder()
                        .onBackPressureWait(1)
                        .build()
                        .start();
                publisher.publish(payload.getBytes(StandardCharsets.UTF_8), Topic.of(config.publishTopic));
            }

            InboundMessage inbound = receiver.receiveMessage(10_000);
            if (inbound == null) {
                throw new IllegalStateException("Timed out waiting for loopback direct message");
            }

            byte[] receivedPayload = inbound.getPayloadAsBytes();
            String received = safePreview(receivedPayload);
            boolean matched = !isBlank(config.publishTopic) && payload.equals(inbound.getPayloadAsString());
            return new Result(
                    "Connected with compressionLevel=" + config.compressionLevel
                            + ", subscribeTopic=" + config.subscribeTopic
                            + ", publishTopic=" + (isBlank(config.publishTopic) ? "<none>" : config.publishTopic)
                            + ", destination=" + inbound.getDestinationName()
                            + ", payloadBytes=" + receivedPayload.length
                            + ", timestamp=" + inbound.getTimeStamp()
                            + ", received=" + received
                            + ", payloadMatched=" + matched);
        } finally {
            terminateQuietly(publisher);
            terminateQuietly(receiver);
            disconnectQuietly(service);
        }
    }

    private static void validate(Config config) {
        if (isBlank(config.host)) throw new IllegalArgumentException("host is required");
        if (isBlank(config.vpn)) throw new IllegalArgumentException("vpn is required");
        if (isBlank(config.username)) throw new IllegalArgumentException("username is required");
        if (config.password == null) throw new IllegalArgumentException("password is required");
        if (isBlank(config.subscribeTopic)) throw new IllegalArgumentException("subscribeTopic is required");
        if (config.compressionLevel < 0 || config.compressionLevel > 9) {
            throw new IllegalArgumentException("compressionLevel must be 0..9");
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private static String safePreview(byte[] payload) {
        int limit = Math.min(payload.length, 48);
        StringBuilder hex = new StringBuilder();
        StringBuilder text = new StringBuilder();
        for (int i = 0; i < limit; i++) {
            int value = payload[i] & 0xff;
            if (i > 0) {
                hex.append(' ');
            }
            if (value < 0x10) {
                hex.append('0');
            }
            hex.append(Integer.toHexString(value));
            text.append(value >= 32 && value <= 126 ? (char) value : '.');
        }
        if (payload.length > limit) {
            hex.append(" ...");
            text.append("...");
        }
        return "hex=[" + hex + "], text=[" + text + "]";
    }

    private static void terminateQuietly(Object lifecycle) {
        if (lifecycle instanceof com.solace.messaging.util.LifecycleControl) {
            try {
                ((com.solace.messaging.util.LifecycleControl) lifecycle).terminate(1_000);
            } catch (Throwable ignored) {
            }
        }
    }

    private static void disconnectQuietly(MessagingService service) {
        if (service == null) {
            return;
        }
        try {
            service.disconnect();
        } catch (Throwable ignored) {
        }
    }

    public static final class Config {
        public final String host;
        public final String vpn;
        public final String username;
        public final String password;
        public final String subscribeTopic;
        public final String publishTopic;
        public final int compressionLevel;

        public Config(
                String host,
                String vpn,
                String username,
                String password,
                String subscribeTopic,
                String publishTopic,
                int compressionLevel) {
            this.host = host;
            this.vpn = vpn;
            this.username = username;
            this.password = password;
            this.subscribeTopic = subscribeTopic;
            this.publishTopic = publishTopic;
            this.compressionLevel = compressionLevel;
        }

        java.util.Properties toProperties() {
            java.util.Properties properties = new java.util.Properties();
            properties.setProperty(SolaceProperties.TransportLayerProperties.HOST, host);
            properties.setProperty(SolaceProperties.ServiceProperties.VPN_NAME, vpn);
            return properties;
        }
    }

    public static final class Result {
        public final String summary;

        Result(String summary) {
            this.summary = summary;
        }
    }
}

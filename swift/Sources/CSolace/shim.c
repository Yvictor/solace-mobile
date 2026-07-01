#include "shim.h"

#include <stdio.h>
#include <string.h>
#include <unistd.h>

typedef struct csolace_smoke_state {
    int messages_received;
    int events_received;
} csolace_smoke_state_t;

static void csolace_print_result(const char *label, solClient_returnCode_t code) {
    printf("%s: %s\n", label, solClient_returnCodeToString(code));
    if (code != SOLCLIENT_OK) {
        solClient_errorInfo_pt error = solClient_getLastErrorInfo();
        printf("  subcode: %s\n", solClient_subCodeToString(error->subCode));
        if (error->errorStr[0] != '\0') {
            printf("  detail: %s\n", error->errorStr);
        }
    }
}

static solClient_rxMsgCallback_returnCode_t csolace_message_callback(solClient_opaqueSession_pt session,
                                                                      solClient_opaqueMsg_pt message,
                                                                      void *user) {
    (void)session;
    csolace_smoke_state_t *state = (csolace_smoke_state_t *)user;
    state->messages_received += 1;

    printf("message received #%d\n", state->messages_received);
    solClient_msg_dump(message, NULL, 0);
    printf("\n");

    return SOLCLIENT_CALLBACK_OK;
}

static void csolace_event_callback(solClient_opaqueSession_pt session,
                                   solClient_session_eventCallbackInfo_pt eventInfo,
                                   void *user) {
    (void)session;
    csolace_smoke_state_t *state = (csolace_smoke_state_t *)user;
    state->events_received += 1;

    printf("session event #%d: %s\n",
           state->events_received,
           solClient_session_eventToString(eventInfo->sessionEvent));
    if (eventInfo->info_p != NULL && eventInfo->info_p[0] != '\0') {
        printf("  info: %s\n", eventInfo->info_p);
    }
}

int csolace_connect_smoke(const char *host,
                          const char *vpn,
                          const char *username,
                          const char *password,
                          const char *topic,
                          const char *compressionLevel,
                          int waitSeconds) {
    solClient_returnCode_t rc = SOLCLIENT_OK;
    solClient_opaqueContext_pt context = NULL;
    solClient_opaqueSession_pt session = NULL;
    solClient_context_createFuncInfo_t contextInfo = SOLCLIENT_CONTEXT_CREATEFUNC_INITIALIZER;
    solClient_session_createFuncInfo_t sessionInfo = SOLCLIENT_SESSION_CREATEFUNC_INITIALIZER;
    csolace_smoke_state_t state = {0, 0};
    const char *sessionProps[32];
    int propIndex = 0;
    int exitCode = 1;

    if (host == NULL || vpn == NULL || username == NULL || password == NULL || topic == NULL) {
        printf("missing required connection input\n");
        return 2;
    }
    if (compressionLevel == NULL || compressionLevel[0] == '\0') {
        compressionLevel = "0";
    }
    if (waitSeconds < 0) {
        waitSeconds = 0;
    }

    printf("host: %s\n", host);
    printf("vpn: %s\n", vpn);
    printf("username: %s\n", username);
    printf("topic: %s\n", topic);
    printf("compression level: %s\n", compressionLevel);

    rc = solClient_initialize(SOLCLIENT_LOG_NOTICE, NULL);
    csolace_print_result("solClient_initialize", rc);
    if (rc != SOLCLIENT_OK) {
        return exitCode;
    }

    rc = solClient_context_create(SOLCLIENT_CONTEXT_PROPS_DEFAULT_WITH_CREATE_THREAD,
                                  &context,
                                  &contextInfo,
                                  sizeof(contextInfo));
    csolace_print_result("solClient_context_create", rc);
    if (rc != SOLCLIENT_OK) {
        goto cleanup;
    }

    sessionInfo.rxMsgInfo.callback_p = csolace_message_callback;
    sessionInfo.rxMsgInfo.user_p = &state;
    sessionInfo.eventInfo.callback_p = csolace_event_callback;
    sessionInfo.eventInfo.user_p = &state;

    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_HOST;
    sessionProps[propIndex++] = host;
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_VPN_NAME;
    sessionProps[propIndex++] = vpn;
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_USERNAME;
    sessionProps[propIndex++] = username;
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_PASSWORD;
    sessionProps[propIndex++] = password;
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_COMPRESSION_LEVEL;
    sessionProps[propIndex++] = compressionLevel;
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_CONNECT_BLOCKING;
    sessionProps[propIndex++] = SOLCLIENT_PROP_ENABLE_VAL;
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_CONNECT_TIMEOUT_MS;
    sessionProps[propIndex++] = "10000";
    sessionProps[propIndex++] = SOLCLIENT_SESSION_PROP_RECONNECT_RETRIES;
    sessionProps[propIndex++] = "0";
    sessionProps[propIndex++] = NULL;

    rc = solClient_session_create(sessionProps,
                                  context,
                                  &session,
                                  &sessionInfo,
                                  sizeof(sessionInfo));
    csolace_print_result("solClient_session_create", rc);
    if (rc != SOLCLIENT_OK) {
        goto cleanup;
    }

    rc = solClient_session_connect(session);
    csolace_print_result("solClient_session_connect", rc);
    if (rc != SOLCLIENT_OK) {
        goto cleanup;
    }

    rc = solClient_session_topicSubscribeExt(session,
                                             SOLCLIENT_SUBSCRIBE_FLAGS_WAITFORCONFIRM,
                                             topic);
    csolace_print_result("solClient_session_topicSubscribeExt", rc);
    if (rc != SOLCLIENT_OK) {
        goto cleanup;
    }

    printf("waiting %d seconds for messages...\n", waitSeconds);
    for (int second = 0; second < waitSeconds; second++) {
        sleep(1);
    }

    printf("messages received: %d\n", state.messages_received);
    exitCode = 0;

    rc = solClient_session_topicUnsubscribeExt(session,
                                               SOLCLIENT_SUBSCRIBE_FLAGS_WAITFORCONFIRM,
                                               topic);
    csolace_print_result("solClient_session_topicUnsubscribeExt", rc);

cleanup:
    if (session != NULL) {
        rc = solClient_session_disconnect(session);
        csolace_print_result("solClient_session_disconnect", rc);

        rc = solClient_session_destroy(&session);
        csolace_print_result("solClient_session_destroy", rc);
    }

    if (context != NULL) {
        rc = solClient_context_destroy(&context);
        csolace_print_result("solClient_context_destroy", rc);
    }

    rc = solClient_cleanup();
    csolace_print_result("solClient_cleanup", rc);

    return exitCode;
}

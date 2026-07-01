#ifndef CSOLACE_SHIM_H
#define CSOLACE_SHIM_H

#define SOLCLIENT_EXCLUDE_DEPRECATED 1
#define SOLCLIENT_CONST_PROPERTIES 1

#include "../../../../solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10/include/solclient/solClient.h"
#include "../../../../solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10/include/solclient/solClientMsg.h"
#include "../../../../solclient_macos/solclient_Darwin-universal2_opt_7.25.0.10/include/solclient/solCache.h"

int csolace_connect_smoke(const char *host,
                          const char *vpn,
                          const char *username,
                          const char *password,
                          const char *topic,
                          const char *compressionLevel,
                          int waitSeconds);

solClient_returnCode_t csolace_context_create_with_thread(solClient_opaqueContext_pt *context);

#endif

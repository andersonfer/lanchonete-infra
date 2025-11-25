package br.com.lanchonete.auth;

public class AuthConfig {
    private final String userPoolId;
    private final String clientId;
    private final String clientesServiceUrl;

    public AuthConfig(String userPoolId, String clientId, String clientesServiceUrl) {
        this.userPoolId = userPoolId;
        this.clientId = clientId;
        this.clientesServiceUrl = clientesServiceUrl;
    }

    public static AuthConfig fromEnvironment() {
        return new AuthConfig(
            System.getenv("USER_POOL_ID"),
            System.getenv("CLIENT_ID"),
            System.getenv("CLIENTES_SERVICE_URL")
        );
    }

    public String getUserPoolId() {
        return userPoolId;
    }

    public String getClientId() {
        return clientId;
    }

    public String getClientesServiceUrl() {
        return clientesServiceUrl;
    }
}
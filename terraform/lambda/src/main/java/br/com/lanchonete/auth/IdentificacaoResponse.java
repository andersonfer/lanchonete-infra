package br.com.lanchonete.auth;

import com.fasterxml.jackson.annotation.JsonProperty;

public class IdentificacaoResponse {
    
    @JsonProperty("accessToken")
    private String accessToken;
    
    @JsonProperty("expiresIn")
    private Integer expiresIn;
    
    @JsonProperty("clienteId")
    private String clienteId;
    
    @JsonProperty("tipo")
    private String tipo;

    public IdentificacaoResponse() {}

    public IdentificacaoResponse(String accessToken, Integer expiresIn, String clienteId, String tipo) {
        this.accessToken = accessToken;
        this.expiresIn = expiresIn;
        this.clienteId = clienteId;
        this.tipo = tipo;
    }

    public String getAccessToken() {
        return accessToken;
    }

    public void setAccessToken(String accessToken) {
        this.accessToken = accessToken;
    }

    public Integer getExpiresIn() {
        return expiresIn;
    }

    public void setExpiresIn(Integer expiresIn) {
        this.expiresIn = expiresIn;
    }

    public String getClienteId() {
        return clienteId;
    }

    public void setClienteId(String clienteId) {
        this.clienteId = clienteId;
    }

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }
}
package br.com.lanchonete.auth;

import com.fasterxml.jackson.annotation.JsonProperty;

public class IdentificacaoRequest {
    
    @JsonProperty("cpf")
    private String cpf;

    public IdentificacaoRequest() {}

    public IdentificacaoRequest(String cpf) {
        this.cpf = cpf;
    }

    public String getCpf() {
        return cpf;
    }

    public void setCpf(String cpf) {
        this.cpf = cpf;
    }
}
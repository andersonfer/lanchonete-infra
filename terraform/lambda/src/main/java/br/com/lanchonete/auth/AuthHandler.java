package br.com.lanchonete.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class AuthHandler implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final CognitoIdentityProviderClient cognitoClient;
    private final ObjectMapper objectMapper;
    private final AuthConfig config;
    private final HttpClient httpClient;

    public AuthHandler() {
        this(AuthConfig.fromEnvironment(),
             CognitoIdentityProviderClient.builder()
                     .region(Region.US_EAST_1)
                     .build(),
             HttpClient.newHttpClient(),
             new ObjectMapper());
    }

    public AuthHandler(AuthConfig config,
                      CognitoIdentityProviderClient cognitoClient,
                      HttpClient httpClient,
                      ObjectMapper objectMapper) {
        this.config = config;
        this.cognitoClient = cognitoClient;
        this.httpClient = httpClient;
        this.objectMapper = objectMapper;
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent input, Context context) {
        context.getLogger().log("Iniciando autenticação via CPF");

        try {
            // Parse do body da requisição
            IdentificacaoRequest request = objectMapper.readValue(input.getBody(), IdentificacaoRequest.class);
            
            if (request.getCpf() == null || request.getCpf().trim().isEmpty()) {
                // Cliente anônimo
                return criarTokenAnonimo(context);
            } else {
                // Cliente identificado via CPF
                return autenticarComCpf(request.getCpf(), context);
            }

        } catch (Exception e) {
            context.getLogger().log("Erro na autenticação: " + e.getMessage());
            return criarErroResponse(500, "Erro interno do servidor");
        }
    }

    private APIGatewayProxyResponseEvent autenticarComCpf(String cpf, Context context) {
        try {
            String cpfLimpo = limparCpf(cpf);
            context.getLogger().log("Autenticando CPF: " + cpfLimpo);

            // 1. Verificar/Criar cliente no MySQL primeiro (fonte da verdade)
            if (!verificarClienteExiste(cpfLimpo, context)) {
                context.getLogger().log("Cliente não existe no MySQL, criando...");
                if (!criarClienteNoMySQL(cpfLimpo, context)) {
                    context.getLogger().log("ERRO CRÍTICO: Falha ao criar cliente no MySQL");
                    return criarErroResponse(500, "Erro ao criar cliente no sistema");
                }
                context.getLogger().log("Cliente criado no MySQL com sucesso");
            } else {
                context.getLogger().log("Cliente já existe no MySQL");
            }

            // 2. Tentar autenticar no Cognito
            AdminInitiateAuthResponse authResponse = null;
            try {
                authResponse = tentarAutenticarCognito(cpfLimpo, context);
            } catch (Exception e) {
                context.getLogger().log("Falha na autenticação, tentando criar usuário no Cognito: " + e.getMessage());

                // Se falhou, criar usuário no Cognito e tentar novamente
                if (!criarUsuarioSeNaoExistir(cpfLimpo, context)) {
                    return criarErroResponse(500, "Erro ao criar usuário de autenticação");
                }

                try {
                    authResponse = tentarAutenticarCognito(cpfLimpo, context);
                } catch (Exception e2) {
                    context.getLogger().log("ERRO CRÍTICO: Falha na autenticação mesmo após criar usuário: " + e2.getMessage());
                    return criarErroResponse(500, "Erro na autenticação");
                }
            }

            // 3. Processar resposta da autenticação
            if (authResponse.challengeName() == ChallengeNameType.NEW_PASSWORD_REQUIRED) {
                authResponse = processarDesafioSenha(authResponse, cpfLimpo, context);
            }

            // 4. Retornar tokens
            AuthenticationResultType result = authResponse.authenticationResult();
            IdentificacaoResponse response = new IdentificacaoResponse(
                    result.idToken(),
                    result.expiresIn(),
                    cpfLimpo,
                    "IDENTIFICADO"
            );

            return criarSucessoResponse(response);

        } catch (Exception e) {
            context.getLogger().log("Erro geral na autenticação: " + e.getMessage());
            return criarErroResponse(400, "Erro na autenticação");
        }
    }

    private APIGatewayProxyResponseEvent criarTokenAnonimo(Context context) {
        try {
            // Para anônimos, criar usuário temporário
            String userId = "anonimo_" + UUID.randomUUID().toString().substring(0, 8);
            
            criarUsuarioSeNaoExistir(userId, context);

            // Autenticar usuário anônimo
            AdminInitiateAuthRequest authRequest = AdminInitiateAuthRequest.builder()
                    .userPoolId(config.getUserPoolId())
                    .clientId(config.getClientId())
                    .authFlow(AuthFlowType.ADMIN_NO_SRP_AUTH)
                    .authParameters(Map.of(
                            "USERNAME", userId,
                            "PASSWORD", "Lanchonete@2024"
                    ))
                    .build();

            AdminInitiateAuthResponse authResponse = cognitoClient.adminInitiateAuth(authRequest);

            // Verificar se precisa definir nova senha
            if (authResponse.challengeName() == ChallengeNameType.NEW_PASSWORD_REQUIRED) {
                // Definir senha permanente automaticamente
                AdminRespondToAuthChallengeRequest challengeRequest = AdminRespondToAuthChallengeRequest.builder()
                        .userPoolId(config.getUserPoolId())
                        .clientId(config.getClientId())
                        .challengeName(ChallengeNameType.NEW_PASSWORD_REQUIRED)
                        .session(authResponse.session())
                        .challengeResponses(Map.of(
                                "USERNAME", userId,
                                "NEW_PASSWORD", "Lanchonete@2024"
                        ))
                        .build();

                AdminRespondToAuthChallengeResponse challengeResponse = cognitoClient.adminRespondToAuthChallenge(challengeRequest);
                authResponse = AdminInitiateAuthResponse.builder()
                        .authenticationResult(challengeResponse.authenticationResult())
                        .build();
            }

            AuthenticationResultType result = authResponse.authenticationResult();
            IdentificacaoResponse response = new IdentificacaoResponse(
                    result.idToken(), // API Gateway Cognito Authorizer precisa do ID Token
                    1800, // 30 minutos para anônimos
                    null,
                    "ANONIMO"
            );

            return criarSucessoResponse(response);

        } catch (Exception e) {
            context.getLogger().log("Erro ao criar token anônimo: " + e.getMessage());
            return criarErroResponse(500, "Erro ao criar sessão anônima");
        }
    }

    private boolean verificarClienteExiste(String cpf, Context context) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(config.getClientesServiceUrl() + "/clientes/cpf/" + cpf))
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                context.getLogger().log("Cliente encontrado no MySQL: " + cpf);
                return true;
            } else if (response.statusCode() == 404) {
                context.getLogger().log("Cliente não encontrado no MySQL: " + cpf);
                return false;
            } else {
                context.getLogger().log("Erro ao verificar cliente no MySQL. Status: " + response.statusCode());
                return false;
            }
        } catch (Exception e) {
            context.getLogger().log("Erro ao conectar com MySQL: " + e.getMessage());
            return false;
        }
    }

    private boolean criarClienteNoMySQL(String cpf, Context context) {
        try {
            Map<String, String> clienteData = new HashMap<>();
            clienteData.put("cpf", cpf);
            clienteData.put("nome", "Cliente " + cpf);
            clienteData.put("email", cpf + "@lanchonete.com");

            String jsonBody = objectMapper.writeValueAsString(clienteData);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(config.getClientesServiceUrl() + "/clientes"))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200 || response.statusCode() == 201) {
                context.getLogger().log("Cliente criado no MySQL: " + cpf);
                return true;
            } else {
                context.getLogger().log("Erro ao criar cliente no MySQL. Status: " + response.statusCode() + ", Body: " + response.body());
                return false;
            }
        } catch (Exception e) {
            context.getLogger().log("Erro ao criar cliente no MySQL: " + e.getMessage());
            return false;
        }
    }

    private AdminInitiateAuthResponse tentarAutenticarCognito(String cpf, Context context) throws Exception {
        AdminInitiateAuthRequest authRequest = AdminInitiateAuthRequest.builder()
                .userPoolId(config.getUserPoolId())
                .clientId(config.getClientId())
                .authFlow(AuthFlowType.ADMIN_NO_SRP_AUTH)
                .authParameters(Map.of(
                        "USERNAME", cpf,
                        "PASSWORD", "Lanchonete@2024"
                ))
                .build();

        return cognitoClient.adminInitiateAuth(authRequest);
    }

    private AdminInitiateAuthResponse processarDesafioSenha(AdminInitiateAuthResponse authResponse, String cpf, Context context) throws Exception {
        AdminRespondToAuthChallengeRequest challengeRequest = AdminRespondToAuthChallengeRequest.builder()
                .userPoolId(config.getUserPoolId())
                .clientId(config.getClientId())
                .challengeName(ChallengeNameType.NEW_PASSWORD_REQUIRED)
                .session(authResponse.session())
                .challengeResponses(Map.of(
                        "USERNAME", cpf,
                        "NEW_PASSWORD", "Lanchonete@2024"
                ))
                .build();

        AdminRespondToAuthChallengeResponse challengeResponse = cognitoClient.adminRespondToAuthChallenge(challengeRequest);
        return AdminInitiateAuthResponse.builder()
                .authenticationResult(challengeResponse.authenticationResult())
                .build();
    }

    private boolean criarUsuarioSeNaoExistir(String username, Context context) {
        try {
            AdminCreateUserRequest createRequest = AdminCreateUserRequest.builder()
                    .userPoolId(config.getUserPoolId())
                    .username(username)
                    .temporaryPassword("Lanchonete@2024")
                    .messageAction(MessageActionType.SUPPRESS) // Não enviar email
                    .build();

            cognitoClient.adminCreateUser(createRequest);
            context.getLogger().log("Usuário criado no Cognito: " + username);
            return true;

        } catch (UsernameExistsException e) {
            context.getLogger().log("Usuário já existe no Cognito: " + username);
            return true;
        } catch (Exception e) {
            context.getLogger().log("Erro ao criar usuário no Cognito: " + e.getMessage());
            return false;
        }
    }

    private String limparCpf(String cpf) {
        return cpf.replaceAll("[^0-9]", "");
    }

    private APIGatewayProxyResponseEvent criarSucessoResponse(Object body) {
        try {
            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(200)
                    .withHeaders(Map.of(
                            "Content-Type", "application/json",
                            "Access-Control-Allow-Origin", "*"
                    ))
                    .withBody(objectMapper.writeValueAsString(body));
        } catch (Exception e) {
            return criarErroResponse(500, "Erro ao serializar resposta");
        }
    }

    private APIGatewayProxyResponseEvent criarErroResponse(int statusCode, String message) {
        Map<String, String> error = Map.of("error", message);
        try {
            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(statusCode)
                    .withHeaders(Map.of(
                            "Content-Type", "application/json",
                            "Access-Control-Allow-Origin", "*"
                    ))
                    .withBody(objectMapper.writeValueAsString(error));
        } catch (Exception e) {
            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(500)
                    .withBody("{\"error\":\"Erro interno\"}");
        }
    }
}
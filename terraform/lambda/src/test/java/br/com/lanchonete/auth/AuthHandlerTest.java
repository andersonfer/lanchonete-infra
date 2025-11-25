package br.com.lanchonete.auth;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.*;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class AuthHandlerTest {

    @Mock
    private CognitoIdentityProviderClient cognitoClient;

    @Mock
    private HttpClient httpClient;

    @Mock
    private Context context;

    @Mock
    private LambdaLogger logger;

    @Mock
    private HttpResponse<String> httpResponse;

    private AuthHandler authHandler;
    private AuthConfig config;
    private ObjectMapper objectMapper;

    @BeforeEach
    public void setUp() {
        config = new AuthConfig("test-pool-id", "test-client-id", "http://localhost:8080");
        objectMapper = new ObjectMapper();
        authHandler = new AuthHandler(config, cognitoClient, httpClient, objectMapper);

        when(context.getLogger()).thenReturn(logger);
    }

    @Test
    @DisplayName("T1 - Deve autenticar com sucesso um cliente anônimo (sem CPF) e retornar token JWT válido com expiração de 30 minutos")
    public void t1() throws Exception {
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": null}");

        AuthenticationResultType authResult = AuthenticationResultType.builder()
                .idToken("test-token-anonimo")
                .accessToken("test-access-token")
                .expiresIn(1800)
                .build();

        AdminInitiateAuthResponse authResponse = AdminInitiateAuthResponse.builder()
                .authenticationResult(authResult)
                .build();

        when(cognitoClient.adminCreateUser(any(AdminCreateUserRequest.class)))
                .thenReturn(AdminCreateUserResponse.builder().build());
        when(cognitoClient.adminInitiateAuth(any(AdminInitiateAuthRequest.class)))
                .thenReturn(authResponse);

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(200, response.getStatusCode());
        assertTrue(response.getBody().contains("\"tipo\":\"ANONIMO\""));
        assertTrue(response.getBody().contains("test-token-anonimo"));
        verify(cognitoClient, times(1)).adminCreateUser(any(AdminCreateUserRequest.class));
        verify(cognitoClient, times(1)).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
    }

    @Test
    @DisplayName("T2 - Deve autenticar com sucesso um cliente existente no MySQL usando CPF e retornar token JWT com dados do cliente")
    public void t2() throws Exception {
        String cpf = "12345678900";
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": \"" + cpf + "\"}");

        when(httpResponse.statusCode()).thenReturn(200);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);

        AuthenticationResultType authResult = AuthenticationResultType.builder()
                .idToken("test-token-cpf")
                .accessToken("test-access-token")
                .expiresIn(3600)
                .build();

        AdminInitiateAuthResponse authResponse = AdminInitiateAuthResponse.builder()
                .authenticationResult(authResult)
                .build();

        when(cognitoClient.adminInitiateAuth(any(AdminInitiateAuthRequest.class)))
                .thenReturn(authResponse);

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(200, response.getStatusCode());
        assertTrue(response.getBody().contains("\"tipo\":\"IDENTIFICADO\""));
        assertTrue(response.getBody().contains("test-token-cpf"));
        assertTrue(response.getBody().contains(cpf));

        verify(httpClient, times(1)).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
        verify(cognitoClient, times(1)).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
    }

    @Test
    @DisplayName("T3 - Deve criar automaticamente um novo cliente no MySQL e Cognito quando CPF não existe e autenticar com sucesso")
    public void t3() throws Exception {
        String cpf = "98765432100";
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": \"" + cpf + "\"}");

        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);
        when(httpResponse.statusCode())
                .thenReturn(404)
                .thenReturn(201);

        AuthenticationResultType authResult = AuthenticationResultType.builder()
                .idToken("test-token-novo-cpf")
                .accessToken("test-access-token")
                .expiresIn(3600)
                .build();

        AdminInitiateAuthResponse authResponse = AdminInitiateAuthResponse.builder()
                .authenticationResult(authResult)
                .build();

        when(cognitoClient.adminInitiateAuth(any(AdminInitiateAuthRequest.class)))
                .thenThrow(new RuntimeException("User not found"))
                .thenReturn(authResponse);

        when(cognitoClient.adminCreateUser(any(AdminCreateUserRequest.class)))
                .thenReturn(AdminCreateUserResponse.builder().build());

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(200, response.getStatusCode());
        assertTrue(response.getBody().contains("\"tipo\":\"IDENTIFICADO\""));

        ArgumentCaptor<HttpRequest> httpRequestCaptor = ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient, times(2)).send(httpRequestCaptor.capture(), any(HttpResponse.BodyHandler.class));

        verify(cognitoClient, times(1)).adminCreateUser(any(AdminCreateUserRequest.class));
        verify(cognitoClient, times(2)).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
    }

    @Test
    @DisplayName("T4 - Deve processar corretamente o desafio NEW_PASSWORD_REQUIRED do Cognito e definir senha permanente automaticamente")
    public void t4() throws Exception {
        String cpf = "11111111111";
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": \"" + cpf + "\"}");

        when(httpResponse.statusCode()).thenReturn(200);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);

        AdminInitiateAuthResponse authResponseComDesafio = AdminInitiateAuthResponse.builder()
                .challengeName(ChallengeNameType.NEW_PASSWORD_REQUIRED)
                .session("test-session")
                .build();

        AuthenticationResultType authResultFinal = AuthenticationResultType.builder()
                .idToken("test-token-final")
                .accessToken("test-access-final")
                .expiresIn(3600)
                .build();

        AdminRespondToAuthChallengeResponse challengeResponse = AdminRespondToAuthChallengeResponse.builder()
                .authenticationResult(authResultFinal)
                .build();

        when(cognitoClient.adminInitiateAuth(any(AdminInitiateAuthRequest.class)))
                .thenReturn(authResponseComDesafio);
        when(cognitoClient.adminRespondToAuthChallenge(any(AdminRespondToAuthChallengeRequest.class)))
                .thenReturn(challengeResponse);

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(200, response.getStatusCode());
        assertTrue(response.getBody().contains("test-token-final"));

        verify(cognitoClient, times(1)).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
        verify(cognitoClient, times(1)).adminRespondToAuthChallenge(any(AdminRespondToAuthChallengeRequest.class));
    }

    @Test
    @DisplayName("T5 - Deve retornar erro 500 quando falha ao criar cliente no MySQL durante processo de auto-cadastro")
    public void t5() throws Exception {
        String cpf = "22222222222";
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": \"" + cpf + "\"}");

        when(httpResponse.statusCode())
                .thenReturn(404)
                .thenReturn(500);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(500, response.getStatusCode());
        assertTrue(response.getBody().contains("\"error\""));

        verify(httpClient, times(2)).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
        verify(cognitoClient, never()).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
    }

    @Test
    @DisplayName("T6 - Deve retornar erro 500 quando recebe JSON inválido no body da requisição")
    public void t6() throws Exception {
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("invalid json");

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(500, response.getStatusCode());
        assertTrue(response.getBody().contains("\"error\""));

        verify(httpClient, never()).send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class));
        verify(cognitoClient, never()).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
    }

    @Test
    @DisplayName("T7 - Deve limpar CPF formatado (com pontos e traços) antes de processar autenticação")
    public void t7() throws Exception {
        String cpfFormatado = "123.456.789-00";
        String cpfLimpo = "12345678900";
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": \"" + cpfFormatado + "\"}");

        when(httpResponse.statusCode()).thenReturn(200);
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class)))
                .thenReturn(httpResponse);

        AuthenticationResultType authResult = AuthenticationResultType.builder()
                .idToken("test-token")
                .accessToken("test-access")
                .expiresIn(3600)
                .build();

        AdminInitiateAuthResponse authResponse = AdminInitiateAuthResponse.builder()
                .authenticationResult(authResult)
                .build();

        when(cognitoClient.adminInitiateAuth(any(AdminInitiateAuthRequest.class)))
                .thenReturn(authResponse);

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(200, response.getStatusCode());
        assertTrue(response.getBody().contains(cpfLimpo));

        ArgumentCaptor<HttpRequest> httpRequestCaptor = ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient, times(1)).send(httpRequestCaptor.capture(), any(HttpResponse.BodyHandler.class));

        HttpRequest capturedRequest = httpRequestCaptor.getValue();
        assertTrue(capturedRequest.uri().toString().contains(cpfLimpo));
    }

    @Test
    @DisplayName("T8 - Deve reutilizar usuário anônimo existente no Cognito quando UsernameExistsException é lançada")
    public void t8() throws Exception {
        String userId = "anonimo_test123";
        APIGatewayProxyRequestEvent request = new APIGatewayProxyRequestEvent();
        request.setBody("{\"cpf\": null}");

        when(cognitoClient.adminCreateUser(any(AdminCreateUserRequest.class)))
                .thenThrow(UsernameExistsException.builder().message("User already exists").build());

        AuthenticationResultType authResult = AuthenticationResultType.builder()
                .idToken("test-token-existing")
                .accessToken("test-access")
                .expiresIn(1800)
                .build();

        AdminInitiateAuthResponse authResponse = AdminInitiateAuthResponse.builder()
                .authenticationResult(authResult)
                .build();

        when(cognitoClient.adminInitiateAuth(any(AdminInitiateAuthRequest.class)))
                .thenReturn(authResponse);

        APIGatewayProxyResponseEvent response = authHandler.handleRequest(request, context);

        assertEquals(200, response.getStatusCode());
        verify(cognitoClient, times(1)).adminCreateUser(any(AdminCreateUserRequest.class));
        verify(cognitoClient, times(1)).adminInitiateAuth(any(AdminInitiateAuthRequest.class));
    }
}
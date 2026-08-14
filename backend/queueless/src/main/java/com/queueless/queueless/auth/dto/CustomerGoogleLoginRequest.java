package com.queueless.queueless.auth.dto;



public class CustomerGoogleLoginRequest {

    private String idToken;

    public String getIdToken() {
        return idToken;
    }

    public void setIdToken(String idToken) {
        this.idToken = idToken;
    }
}
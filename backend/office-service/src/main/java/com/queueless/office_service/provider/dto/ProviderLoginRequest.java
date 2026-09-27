package com.queueless.office_service.provider.dto;

public class ProviderLoginRequest {

    private String officeId;
    private String username;
    private String password;

    public ProviderLoginRequest() {
    }

    public ProviderLoginRequest(String officeId, String username, String password) {
        this.officeId = officeId;
        this.username = username;
        this.password = password;
    }

    public String getOfficeId() {
        return officeId;
    }

    public void setOfficeId(String officeId) {
        this.officeId = officeId;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}

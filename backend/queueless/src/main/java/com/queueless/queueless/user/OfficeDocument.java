package com.queueless.queueless.user;



import java.time.LocalDateTime;

import com.fasterxml.jackson.annotation.JsonIgnore;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "office_documents")
public class OfficeDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "office_profile_id", nullable = false)
    @JsonIgnore
    private OfficeProfile officeProfile;

    @Column(nullable = false)
    private String documentType; // e.g. "CLINIC_REGISTRATION", "DOCTOR_DEGREE", "TRADE_LICENSE", "GOVT_ID"

    @Column(nullable = false)
    private String originalFileName;

    @Column(nullable = false)
    private String fileUrl; // Path or URL to access the uploaded file

    private String contentType;
    private Long fileSize;

    private LocalDateTime uploadedAt = LocalDateTime.now();

    // Getters and Setters...
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public OfficeProfile getOfficeProfile() { return officeProfile; }
    public void setOfficeProfile(OfficeProfile officeProfile) { this.officeProfile = officeProfile; }
    public String getDocumentType() { return documentType; }
    public void setDocumentType(String documentType) { this.documentType = documentType; }
    public String getOriginalFileName() { return originalFileName; }
    public void setOriginalFileName(String originalFileName) { this.originalFileName = originalFileName; }
    public String getFileUrl() { return fileUrl; }
    public void setFileUrl(String fileUrl) { this.fileUrl = fileUrl; }
    public String getContentType() { return contentType; }
    public void setContentType(String contentType) { this.contentType = contentType; }
    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }
    public LocalDateTime getUploadedAt() { return uploadedAt; }
    public void setUploadedAt(LocalDateTime uploadedAt) { this.uploadedAt = uploadedAt; }
}
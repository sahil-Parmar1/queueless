package com.queueless.customer_service.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.queueless.customer_service.model.CustomerFavoriteOffice;

@Repository
public interface CustomerFavoriteOfficeRepository extends JpaRepository<CustomerFavoriteOffice, Long> {

    boolean existsByCustomerIdAndOfficeId(Long customerId, Long officeId);

    boolean existsByCustomerEmailAndOfficeId(String customerEmail, Long officeId);

    Optional<CustomerFavoriteOffice> findByCustomerIdAndOfficeId(Long customerId, Long officeId);

    Optional<CustomerFavoriteOffice> findByCustomerEmailAndOfficeId(String customerEmail, Long officeId);

    List<CustomerFavoriteOffice> findByCustomerIdOrderByCreatedAtDesc(Long customerId);

    List<CustomerFavoriteOffice> findByCustomerEmailOrderByCreatedAtDesc(String customerEmail);

    void deleteByCustomerIdAndOfficeId(Long customerId, Long officeId);

    void deleteByCustomerEmailAndOfficeId(String customerEmail, Long officeId);

    @Query("SELECT f.office.id FROM CustomerFavoriteOffice f WHERE f.customerId = :customerId")
    List<Long> findFavoriteOfficeIdsByCustomerId(@Param("customerId") Long customerId);

    @Query("SELECT f.office.id FROM CustomerFavoriteOffice f WHERE f.customerEmail = :customerEmail")
    List<Long> findFavoriteOfficeIdsByCustomerEmail(@Param("customerEmail") String customerEmail);
}

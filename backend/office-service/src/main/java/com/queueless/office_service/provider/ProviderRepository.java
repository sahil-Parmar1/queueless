package com.queueless.office_service.provider;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProviderRepository extends JpaRepository<Provider, Long> {

    List<Provider> findByOfficeIdOrderByIdAsc(Long officeId);

    List<Provider> findByOfficeIdAndActiveTrueOrderByIdAsc(Long officeId);

    Optional<Provider> findByIdAndOfficeId(Long id, Long officeId);

    boolean existsByOfficeIdAndNameIgnoreCase(Long officeId, String name);

    Optional<Provider> findByOfficeIdAndUsernameIgnoreCase(Long officeId, String username);

    boolean existsByOfficeIdAndUsernameIgnoreCase(Long officeId, String username);

    Optional<Provider> findByOfficeOfficeIdAndUsernameIgnoreCase(String officeId, String username);
}

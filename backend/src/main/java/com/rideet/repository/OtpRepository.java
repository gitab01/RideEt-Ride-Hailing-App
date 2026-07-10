package com.rideet.repository;

import com.rideet.domain.entity.OtpVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Repository
public interface OtpRepository extends JpaRepository<OtpVerification, Long> {

    Optional<OtpVerification> findTopByIdentifierAndPurposeAndUsedFalseOrderByCreatedAtDesc(
            String identifier, String purpose
    );

    @Modifying
    @Transactional
    @Query("UPDATE OtpVerification o SET o.used = true WHERE o.identifier = :identifier AND o.purpose = :purpose")
    void invalidateAllForIdentifierAndPurpose(String identifier, String purpose);
}

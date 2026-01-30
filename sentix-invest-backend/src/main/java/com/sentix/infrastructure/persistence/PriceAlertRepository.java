package com.sentix.infrastructure.persistence;

import com.sentix.domain.PriceAlert;
import com.sentix.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PriceAlertRepository extends JpaRepository<PriceAlert, UUID> {

    List<PriceAlert> findByUser(User user);

    List<PriceAlert> findByUserAndSymbol(User user, String symbol);

    List<PriceAlert> findByIsActiveTrue();

    List<PriceAlert> findByUserAndIsActiveTrue(User user);
}

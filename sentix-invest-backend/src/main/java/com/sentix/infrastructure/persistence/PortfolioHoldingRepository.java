package com.sentix.infrastructure.persistence;

import com.sentix.domain.PortfolioHolding;
import com.sentix.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PortfolioHoldingRepository extends JpaRepository<PortfolioHolding, UUID> {

    List<PortfolioHolding> findByUser(User user);

    Optional<PortfolioHolding> findByUserAndSymbol(User user, String symbol);

    boolean existsByUserAndSymbol(User user, String symbol);

    void deleteByUserAndSymbol(User user, String symbol);
}

package com.sentix.infrastructure.persistence;

import com.sentix.domain.User;
import com.sentix.domain.Watchlist;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WatchlistRepository extends JpaRepository<Watchlist, UUID> {

    List<Watchlist> findByUser(User user);

    Page<Watchlist> findByUser(User user, Pageable pageable);

    Optional<Watchlist> findByUserAndSymbol(User user, String symbol);

    boolean existsByUserAndSymbol(User user, String symbol);

    void deleteByUserAndSymbol(User user, String symbol);
}

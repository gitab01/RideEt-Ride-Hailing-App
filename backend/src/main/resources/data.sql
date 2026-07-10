-- Seed admin user (password: Admin@1234)
-- BCrypt hash of 'Admin@1234'
INSERT INTO users (first_name, last_name, email, phone, password, role, enabled, account_non_locked, email_verified, phone_verified, wallet_balance, created_at, updated_at)
SELECT 'Super', 'Admin', 'admin@rideet.com', '+10000000000',
       '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
       'ADMIN', 1, 1, 1, 1, 0.0, GETDATE(), GETDATE()
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@rideet.com');

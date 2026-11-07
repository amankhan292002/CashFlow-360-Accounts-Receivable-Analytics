-- 1. Regions Table
CREATE TABLE regions (
    region_id VARCHAR(10) PRIMARY KEY,
    region_name VARCHAR(50)
);

-- 2. Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(100),
    industry VARCHAR(100),
    customer_segment VARCHAR(30),
    city VARCHAR(50),
    region_id VARCHAR(10) REFERENCES regions(region_id),
    credit_limit NUMERIC(15,2),
    customer_since DATE
);

-- 3. Invoices Table
CREATE TABLE invoices (
    invoice_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20) REFERENCES customers(customer_id),
    invoice_date DATE,
    payment_terms_days INTEGER,
    due_date DATE,
    invoice_amount NUMERIC(15,2),
    currency VARCHAR(10),
    invoice_status VARCHAR(30)
);

-- 4. Payments Table
CREATE TABLE payments (
    payment_id VARCHAR(20) PRIMARY KEY,
    invoice_id VARCHAR(20) REFERENCES invoices(invoice_id),
    payment_date DATE,
    payment_amount NUMERIC(15,2),
    payment_method VARCHAR(50),
    payment_reference VARCHAR(30)
);

-- Check total rows in all four tables

SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'regions', COUNT(*) FROM regions;

-- Check missing values in customer records

SELECT
    COUNT(*) FILTER (WHERE customer_name IS NULL) AS missing_names,
    COUNT(*) FILTER (WHERE industry IS NULL) AS missing_industry,
    COUNT(*) FILTER (WHERE city IS NULL) AS missing_city,
    COUNT(*) FILTER (WHERE credit_limit IS NULL) AS missing_credit_limit
FROM customers;

-- Identify customers with missing city

SELECT customer_id, customer_name, city, region_id
FROM customers
WHERE city IS NULL;

-- Check missing values in remaining customer columns

SELECT
    COUNT(*) FILTER (WHERE region_id IS NULL) AS missing_region,
    COUNT(*) FILTER (WHERE customer_segment IS NULL) AS missing_segment,
    COUNT(*) FILTER (WHERE customer_since IS NULL) AS missing_joining_date
FROM customers;

-- Check missing values in invoice records

SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS missing_customer,
    COUNT(*) FILTER (WHERE invoice_date IS NULL) AS missing_invoice_date,
    COUNT(*) FILTER (WHERE due_date IS NULL) AS missing_due_date,
    COUNT(*) FILTER (WHERE invoice_amount IS NULL) AS missing_amount,
    COUNT(*) FILTER (WHERE invoice_status IS NULL) AS missing_status,
    COUNT(*) FILTER (WHERE payment_terms_days IS NULL) AS missing_payment_terms
FROM invoices;

-- Inspect invoices with missing payment terms

SELECT
    invoice_id,
    invoice_date,
    due_date,
    (due_date - invoice_date) AS calculated_terms
FROM invoices
WHERE payment_terms_days IS NULL;

-- Check calculated payment terms for all 15 invoices

SELECT
    (due_date - invoice_date) AS calculated_terms,
    COUNT(*) AS total_invoices
FROM invoices
WHERE payment_terms_days IS NULL
GROUP BY calculated_terms
ORDER BY calculated_terms;

-- Fill missing payment terms using invoice and due dates

UPDATE invoices
SET payment_terms_days = due_date - invoice_date
WHERE payment_terms_days IS NULL;

-- Verify missing payment terms after update

SELECT COUNT(*) AS remaining_missing
FROM invoices
WHERE payment_terms_days IS NULL;

-- Check missing values in payments
SELECT
    COUNT(*) FILTER (WHERE invoice_id IS NULL) AS missing_invoice_id,
    COUNT(*) FILTER (WHERE payment_date IS NULL) AS missing_payment_date,
    COUNT(*) FILTER (WHERE payment_amount IS NULL) AS missing_amount,
    COUNT(*) FILTER (WHERE payment_method IS NULL) AS missing_method
FROM payments;

-- Check duplicate payment IDs
SELECT
    payment_id,
    COUNT(*) AS total_records
FROM payments
GROUP BY payment_id
HAVING COUNT(*) > 1;

-- Check zero or negative payment amounts
SELECT *
FROM payments
WHERE payment_amount <= 0;

-- Check payments made before invoice date
SELECT
    p.payment_id,
    p.invoice_id,
    p.payment_date,
    i.invoice_date
FROM payments p
JOIN invoices i
    ON p.invoice_id = i.invoice_id
WHERE p.payment_date < i.invoice_date;

-- Check payments without a matching invoice
SELECT p.*
FROM payments p
LEFT JOIN invoices i
    ON p.invoice_id = i.invoice_id
WHERE i.invoice_id IS NULL;

-- Check duplicate customer IDs
SELECT
    customer_id,
    COUNT(*) AS total_records
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Check duplicate customer names
SELECT
    customer_name,
    COUNT(*) AS total_records
FROM customers
GROUP BY customer_name
HAVING COUNT(*) > 1;

-- Check zero or negative credit limits
SELECT *
FROM customers
WHERE credit_limit <= 0;

-- Check extra spaces in industry names
SELECT DISTINCT industry
FROM customers
WHERE industry <> TRIM(industry);

-- Check blank industry values
SELECT *
FROM customers
WHERE TRIM(industry) = '';

-- Check customer segment distribution
SELECT
    customer_segment,
    COUNT(*) AS total_customers
FROM customers
GROUP BY customer_segment
ORDER BY total_customers DESC;

-- Check future customer joining dates
SELECT *
FROM customers
WHERE customer_since > CURRENT_DATE;

-- Check invalid customer region references
SELECT c.*
FROM customers c
LEFT JOIN regions r
    ON c.region_id = r.region_id
WHERE r.region_id IS NULL;

-- Check duplicate invoice IDs
SELECT
    invoice_id,
    COUNT(*) AS total_records
FROM invoices
GROUP BY invoice_id
HAVING COUNT(*) > 1;

-- Check zero or negative invoice amounts
SELECT *
FROM invoices
WHERE invoice_amount <= 0;

-- Check invalid invoice due dates
SELECT *
FROM invoices
WHERE due_date < invoice_date;

-- Check invalid payment terms
SELECT *
FROM invoices
WHERE payment_terms_days <= 0;

-- Check invoice status distribution
SELECT
    invoice_status,
    COUNT(*) AS total_invoices
FROM invoices
GROUP BY invoice_status
ORDER BY total_invoices DESC;

-- Check invoices without a matching customer
SELECT i.*
FROM invoices i
LEFT JOIN customers c
    ON i.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Check future invoice dates
SELECT *
FROM invoices
WHERE invoice_date > CURRENT_DATE;

-- Check invoice currency distribution
SELECT
    currency,
    COUNT(*) AS total_invoices
FROM invoices
GROUP BY currency
ORDER BY total_invoices DESC;

-- Check distinct invoice statuses
SELECT DISTINCT invoice_status
FROM invoices
ORDER BY invoice_status;

-- Check duplicate region IDs
SELECT
    region_id,
    COUNT(*) AS total_records
FROM regions
GROUP BY region_id
HAVING COUNT(*) > 1;

-- Check customers by region
SELECT
    r.region_name,
    COUNT(c.customer_id) AS total_customers
FROM regions r
LEFT JOIN customers c
    ON r.region_id = c.region_id
GROUP BY r.region_name
ORDER BY total_customers DESC;

-- Check duplicate region names
SELECT
    region_name,
    COUNT(*) AS total_records
FROM regions
GROUP BY region_name
HAVING COUNT(*) > 1;

---Financial Overview

-----total invoiced amount
SELECT
    SUM(invoice_amount) AS total_invoiced
FROM invoices;

-- total collected amount
SELECT
    SUM(payment_amount) AS total_collected
FROM payments;

---total outstanding amount
SELECT
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS total_outstanding
FROM invoices i
LEFT JOIN (
    SELECT
        invoice_id,
        SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p
    ON i.invoice_id = p.invoice_id;

---total outstanding amount
SELECT
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS total_outstanding
FROM invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id;

--- overall collection rate
SELECT
    ROUND(
        (SUM(payment_amount) / 
        (SELECT SUM(invoice_amount) FROM invoices)) * 100,
        2
    ) AS collection_rate
FROM payments;

--- Overdue Invoice Analysis

---total overdue amount
SELECT
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS overdue_amount
FROM invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0);

-- Count overdue invoices
SELECT
    COUNT(*) AS overdue_invoices
FROM invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0);

--- average overdue amount per invoice
SELECT
    ROUND(AVG(i.invoice_amount - COALESCE(p.total_paid, 0)), 2)
        AS avg_overdue_amount
FROM invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0);

--- Invoice Aging Analysis

-- Calculate outstanding by aging bucket
SELECT
    CASE
        WHEN CURRENT_DATE - i.due_date <= 30 THEN '0-30 Days'
        WHEN CURRENT_DATE - i.due_date <= 60 THEN '31-60 Days'
        WHEN CURRENT_DATE - i.due_date <= 90 THEN '61-90 Days'
        ELSE '90+ Days'
    END AS aging_bucket,
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS outstanding_amount
FROM invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0)
GROUP BY aging_bucket
ORDER BY MIN(i.due_date);

-- Count overdue invoices by aging bucket
SELECT
    CASE
        WHEN CURRENT_DATE - i.due_date <= 30 THEN '0-30 Days'
        WHEN CURRENT_DATE - i.due_date <= 60 THEN '31-60 Days'
        WHEN CURRENT_DATE - i.due_date <= 90 THEN '61-90 Days'
        ELSE '90+ Days'
    END AS aging_bucket,
    COUNT(*) AS total_invoices
FROM invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0)
GROUP BY aging_bucket
ORDER BY MIN(i.due_date);

--- Customer Payment Behaviour Analysis

--- top 10 customers by outstanding amount
SELECT
    c.customer_name,
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS outstanding_amount
FROM customers c
JOIN invoices i
    ON c.customer_id = i.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.invoice_amount > COALESCE(p.total_paid, 0)
GROUP BY c.customer_name
ORDER BY outstanding_amount DESC
LIMIT 10;

-- Find customers with highest average payment delay
SELECT
    c.customer_name,
    COUNT(*) AS late_payments,
    ROUND(AVG(p.payment_date - i.due_date), 2) AS avg_days_late
FROM payments p
JOIN invoices i
    ON p.invoice_id = i.invoice_id
JOIN customers c
    ON i.customer_id = c.customer_id
WHERE p.payment_date > i.due_date
GROUP BY c.customer_name
ORDER BY avg_days_late DESC
LIMIT 10;

---Collection Performance Analysis

--- collection rate by customer segment
SELECT
    c.customer_segment,
    SUM(p.payment_amount) AS total_collected,
    SUM(i.invoice_amount) AS total_invoiced,
    ROUND(
        SUM(p.payment_amount) /
        SUM(i.invoice_amount) * 100, 2
    ) AS collection_rate
FROM customers c
JOIN invoices i
    ON c.customer_id = i.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS payment_amount
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
GROUP BY c.customer_segment
ORDER BY collection_rate DESC;

--- collection rate by region
SELECT
    r.region_name,
    SUM(p.payment_amount) AS total_collected,
    SUM(i.invoice_amount) AS total_invoiced,
    ROUND(
        SUM(p.payment_amount) /
        SUM(i.invoice_amount) * 100, 2
    ) AS collection_rate
FROM regions r
JOIN customers c
    ON r.region_id = c.region_id
JOIN invoices i
    ON c.customer_id = i.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS payment_amount
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
GROUP BY r.region_name
ORDER BY collection_rate DESC;

--- monthly collection trend
SELECT
    DATE_TRUNC('month', payment_date)::DATE AS collection_month,
    SUM(payment_amount) AS total_collected
FROM payments
GROUP BY collection_month
ORDER BY collection_month;

--- Analyse collections by payment method
SELECT
    payment_method,
    COUNT(*) AS total_payments,
    SUM(payment_amount) AS total_collected
FROM payments
GROUP BY payment_method
ORDER BY total_collected DESC;

--- Collection Priority Analysis

-- Identify high-priority overdue invoices
SELECT
    i.invoice_id,
    c.customer_name,
    i.invoice_amount - COALESCE(p.total_paid, 0) AS outstanding_amount,
    CURRENT_DATE - i.due_date AS overdue_days
FROM invoices i
JOIN customers c
    ON i.customer_id = c.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0)
ORDER BY outstanding_amount DESC, overdue_days DESC
LIMIT 20;

-- Categorize overdue invoices by priority
SELECT
    i.invoice_id,
    c.customer_name,
    i.invoice_amount - COALESCE(p.total_paid, 0) AS outstanding_amount,
    CURRENT_DATE - i.due_date AS overdue_days,
    CASE
        WHEN i.invoice_amount - COALESCE(p.total_paid, 0) >= 500000
             AND CURRENT_DATE - i.due_date > 90
            THEN 'High'
        WHEN i.invoice_amount - COALESCE(p.total_paid, 0) >= 200000
            THEN 'Medium'
        ELSE 'Low'
    END AS priority
FROM invoices i
JOIN customers c ON i.customer_id = c.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0)
ORDER BY outstanding_amount DESC
LIMIT 20;


---Customer Risk Analysis

-- Analyse customer-wise overdue risk
SELECT
    c.customer_name,
    COUNT(*) AS overdue_invoices,
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS outstanding_amount
FROM customers c
JOIN invoices i ON c.customer_id = i.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0)
GROUP BY c.customer_name
ORDER BY outstanding_amount DESC
LIMIT 10;

-- customers with highest overdue invoice count
SELECT
    c.customer_name,
    COUNT(*) AS overdue_invoices,
    SUM(i.invoice_amount - COALESCE(p.total_paid, 0)) AS outstanding_amount
FROM customers c
JOIN invoices i ON c.customer_id = i.customer_id
LEFT JOIN (
    SELECT invoice_id, SUM(payment_amount) AS total_paid
    FROM payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id
WHERE i.due_date < CURRENT_DATE
AND i.invoice_amount > COALESCE(p.total_paid, 0)
GROUP BY c.customer_name
ORDER BY overdue_invoices DESC
LIMIT 10;

---Business Summary & Recommendations

-- Generate overall business performance summary
SELECT
    (SELECT SUM(invoice_amount) FROM invoices) AS total_invoiced,
    (SELECT SUM(payment_amount) FROM payments) AS total_collected,
    (SELECT SUM(invoice_amount) FROM invoices)
      - (SELECT SUM(payment_amount) FROM payments) AS outstanding_amount,
    (SELECT COUNT(*) FROM invoices) AS total_invoices,
    (SELECT COUNT(*)
     FROM invoices i
     LEFT JOIN (
         SELECT invoice_id, SUM(payment_amount) AS total_paid
         FROM payments
         GROUP BY invoice_id
     ) p ON i.invoice_id = p.invoice_id
     WHERE i.due_date < CURRENT_DATE
       AND i.invoice_amount > COALESCE(p.total_paid, 0)
    ) AS overdue_invoices;














































DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;
CREATE TABLE books (
book_id          SERIAL PRIMARY KEY,
title            VARCHAR(100) NOT NULL UNIQUE,
total_copies     INT NOT NULL CHECK (total_copies > 0),
available_copies INT NOT NULL,
CHECK (available_copies >= 0 AND available_copies 
<= total_copies)
);
CREATE TABLE book_loans (
loan_id        SERIAL PRIMARY KEY,
student_number VARCHAR(20) NOT NULL,
book_id   INT NOT NULL REFERENCES books(book_id),
quantity       INT NOT NULL CHECK (quantity > 0),
status         VARCHAR(10) NOT NULL DEFAULT 
'BORROWED'
CHECK (status IN ('BORROWED', 'RETURNED')),
loaned_at     TIMESTAMP NOT NULL DEFAULT NOW(), 
returned_at    TIMESTAMP );
INSERT INTO books (title, total_copies, 
available_copies) VALUES
('Database Systems',  6, 6),   -- sufficiently stocked
('Operating Systems', 3, 2),   -- low
('Computer Networks', 4, 0);   -- unavailable
SELECT * FROM books ORDER BY book_id;
DO $$
DECLARE
r     
RECORD;
v_msg TEXT;
BEGIN
FOR r IN SELECT title, available_copies FROM books 
ORDER BY book_id LOOP
IF r.available_copies = 0 THEN
v_msg := 'UNAVAILABLE';
ELSIF r.available_copies <= 2 THEN
v_msg := 'LOW on copies (' || 
r.available_copies || ')';
ELSE
v_msg := 'SUFFICIENTLY stocked (' || 
r.available_copies || ')';
END IF;
RAISE NOTICE 'Book "%": %', r.title, v_msg;
END LOOP;
END $$;
DO $$
DECLARE
v_reminder INT := 1;
BEGIN
WHILE v_reminder <= 3 LOOP
RAISE NOTICE 'Overdue reminder number %', 
v_reminder;
v_reminder := v_reminder + 1;
END LOOP;
FOR shelf IN 1..3 LOOP
RAISE NOTICE 'Library shelf number %', shelf;
END LOOP;
END $$;
CREATE OR REPLACE PROCEDURE 
borrow_book(p_student_number VARCHAR, p_book_id INT, 
p_quantity INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_available INT;
v_title     
VARCHAR(100);
BEGIN-- Validate input
IF p_student_number IS NULL OR 
TRIM(p_student_number) = '' THEN
RAISE EXCEPTION 'Student number cannot be 
blank';
END IF;
IF p_quantity IS NULL OR p_quantity <= 0 THEN
RAISE EXCEPTION 'Invalid quantity: % (must be 
at least 1)', p_quantity;
END IF;-- Lock the row so concurrent loans cannot oversell the stock
SELECT available_copies, title
INTO v_available, v_title
FROM books
WHERE book_id = p_book_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Book % does not exist', 
p_book_id;
END IF;
IF p_quantity > v_available THEN
RAISE NOTICE 'Loan REJECTED: % requested % 
copies of "%" but only % available',
p_student_number, p_quantity, v_title, 
v_available;
RETURN;
END IF;
UPDATE books
SET available_copies = available_copies - 
p_quantity
WHERE book_id = p_book_id;
INSERT INTO book_loans (student_number, book_id, 
quantity)
VALUES (TRIM(p_student_number), p_book_id, 
p_quantity);
RAISE NOTICE 'Loan recorded: % borrowed % 
copy/copies of "%"',
p_student_number, p_quantity, v_title;
END $$;
CALL borrow_book('S2026001', 1, 2);   -- valid: 
CALL borrow_book('S2026002', 2, 1);   -- valid: 
CALL borrow_book('S2026003', 2, 5);   -- rejected: 
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_status   VARCHAR(10);
v_book_id  INT;
v_quantity INT;
BEGIN
SELECT status, book_id, quantity
INTO v_status, v_book_id, v_quantity
FROM book_loans
WHERE loan_id = p_loan_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Loan % does not exist', 
p_loan_id;
END IF;
IF v_status = 'RETURNED' THEN
RAISE NOTICE 'Loan % already returned - no 
copies restored', p_loan_id;
RETURN;
END IF;
UPDATE books
SET available_copies = available_copies + 
v_quantity
WHERE book_id = v_book_id;
UPDATE book_loans
SET status = 'RETURNED',
returned_at = NOW()
WHERE loan_id = p_loan_id;
RAISE NOTICE 'Loan % returned - % copy/copies 
restored', p_loan_id, v_quantity;
END $$;
CALL return_book(1);   -- restores copies
CALL return_book(1);   -- second call: must not restore again
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
DO $$
DECLARE
cur_books CURSOR FOR
SELECT title, available_copies
FROM books
WHERE available_copies <= 2
ORDER BY book_id;
v_title books.title%TYPE;
v_avail books.available_copies%TYPE;
BEGIN
OPEN cur_books;
LOOP
FETCH cur_books INTO v_title, v_avail;
EXIT WHEN NOT FOUND;
RAISE NOTICE 'Few copies left: "%" (% 
available)', v_title, v_avail;
END LOOP;
CLOSE cur_books;
END $$;
DO $$
BEGIN
CALL borrow_book('S2026004', 1, 0);
EXCEPTION
WHEN raise_exception THEN
RAISE NOTICE 'Invalid input handled: %', 
SQLERRM;
END $$;
SELECT book_id, title, total_copies, available_copies
FROM books
ORDER BY book_id;
SELECT loan_id, student_number, book_id, quantity, 
status, loaned_at, returned_at
FROM book_loans
ORDER BY loan_id

      







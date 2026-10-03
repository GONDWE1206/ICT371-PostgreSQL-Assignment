DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;
CREATE TABLE medicines (
medicine_id    SERIAL PRIMARY KEY,
medicine_name  VARCHAR(100) NOT NULL UNIQUE,
stock_quantity INT NOT NULL CHECK (stock_quantity 
>= 0)
);
CREATE TABLE dispensing_records (
record_id    SERIAL PRIMARY KEY,  
      
student_number VARCHAR(20) NOT NULL,
medicine_id    INT NOT NULL REFERENCES 
medicines(medicine_id),
quantity INT NOT NULL CHECK (quantity > 0),
status    VARCHAR(10) NOT NULL DEFAULT 
'DISPENSED'
  CHECK (status IN ('DISPENSED', 
'REVERSED')),
dispensed_at   TIMESTAMP NOT NULL DEFAULT NOW(),
reversed_at    TIMESTAMP ); 
INSERT INTO medicines (medicine_name, stock_quantity) 
VALUES
('Paracetamol 500mg',     100),   -- sufficiently stocked
('Amoxicillin 250mg',       8),   -- low
('Oral Rehydration Salts',  0);   -- out of stock
SELECT * FROM medicines ORDER BY medicine_id;
DO $$
DECLARE
r     
RECORD;
v_msg TEXT;
BEGIN
FOR r IN SELECT medicine_name, stock_quantity FROM 
medicines ORDER BY medicine_id LOOP
IF r.stock_quantity = 0 THEN
v_msg := 'OUT OF STOCK';
ELSIF r.stock_quantity <= 10 THEN
v_msg := 'LOW on stock (' || 
r.stock_quantity || ')';
ELSE
v_msg := 'SUFFICIENTLY stocked (' || 
r.stock_quantity || ')';
END IF;
RAISE NOTICE '%: %', r.medicine_name, v_msg;
END LOOP;
END $$;
DO $$
DECLARE
v_day INT := 1;
BEGIN
WHILE v_day <= 3 LOOP
RAISE NOTICE 'Stock review day %', v_day;
v_day := v_day + 1;
END LOOP;
FOR i IN 1..3 LOOP
RAISE NOTICE 'Shelf inspection number %', i;
END LOOP;
END $$;
CREATE OR REPLACE PROCEDURE 
dispense_medicine(p_student_number VARCHAR, 
p_medicine_id INT, p_quantity INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_stock INT;
v_name  VARCHAR(100);
BEGIN-- Validate input
IF p_student_number IS NULL OR 
TRIM(p_student_number) = '' THEN
RAISE EXCEPTION 'Student number cannot be 
blank';
END IF;
IF p_quantity IS NULL OR p_quantity <= 0 THEN
RAISE EXCEPTION 'Invalid dispensing quantity: 
% (must be at least 1)', p_quantity;
END IF;
SELECT stock_quantity, medicine_name
INTO v_stock, v_name
FROM medicines
WHERE medicine_id = p_medicine_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Medicine % does not exist', 
p_medicine_id;
END IF;
IF p_quantity > v_stock THEN
RAISE NOTICE 'Dispensing REJECTED: % requested 
% of % but only % in stock',
p_student_number, p_quantity, v_name, 
v_stock;
RETURN;
END IF;
UPDATE medicines
SET stock_quantity = stock_quantity - 
p_quantity
WHERE medicine_id = p_medicine_id;
INSERT INTO dispensing_records (student_number, 
medicine_id, quantity)
VALUES (TRIM(p_student_number), p_medicine_id, 
p_quantity);
RAISE NOTICE 'Dispensed % of % to student %', 
p_quantity, v_name, p_student_number;
END $$;
CALL dispense_medicine('S2026001', 1, 20);   -- valid: Paracetamol
CALL dispense_medicine('S2026002', 2, 3);    
CALL dispense_medicine('S2026003', 2, 20);   -- rejected: only 5 left-- valid: 
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
CREATE OR REPLACE PROCEDURE 
reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_status      
VARCHAR(10);
v_medicine_id INT;
v_quantity    
INT;
BEGIN
SELECT status, medicine_id, quantity
INTO v_status, v_medicine_id, v_quantity
FROM dispensing_records
WHERE record_id = p_record_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Dispensing record % does not 
exist', p_record_id;
END IF;
IF v_status = 'REVERSED' THEN
RAISE NOTICE 'Record % already reversed - 
stock not restored again', p_record_id;
RETURN;
END IF;
UPDATE medicines
SET stock_quantity = stock_quantity + 
v_quantity
WHERE medicine_id = v_medicine_id;
UPDATE dispensing_records
SET status = 'REVERSED',
reversed_at = NOW()
WHERE record_id = p_record_id;
RAISE NOTICE 'Record % reversed - % units restored 
to stock', p_record_id, v_quantity;
END $$;
CALL reverse_dispensing(1);   -- restores stock
CALL reverse_dispensing(1);   -- second call: stock must not be restored again
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
DO $$
DECLARE
cur_low CURSOR (p_threshold INT) FOR
SELECT medicine_name, stock_quantity
FROM medicines
WHERE stock_quantity < p_threshold
ORDER BY medicine_id;
v_name  medicines.medicine_name%TYPE;
v_stock medicines.stock_quantity%TYPE;
BEGIN
OPEN cur_low(10);   -- low-stock threshold = 10
LOOP
FETCH cur_low INTO v_name, v_stock;
EXIT WHEN NOT FOUND;
RAISE NOTICE 'Below threshold: % (stock %)', 
v_name, v_stock;
END LOOP;
CLOSE cur_low;
END $$;
DO $$
BEGIN
CALL dispense_medicine('S2026004', 1, -5);
EXCEPTION
WHEN raise_exception THEN
RAISE NOTICE 'Invalid input handled: %', 
SQLERRM;
END $$;
SELECT medicine_id, medicine_name, stock_quantity
FROM medicines
ORDER BY medicine_id;
SELECT record_id, student_number, medicine_id, 
quantity, status, dispensed_at, reversed_at
FROM dispensing_records
ORDER BY record_id;
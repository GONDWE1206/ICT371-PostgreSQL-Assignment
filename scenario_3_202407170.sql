DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;
CREATE TABLE hostel_rooms (
room_id          SERIAL PRIMARY KEY,
room_name        VARCHAR(20) NOT NULL UNIQUE,
total_spaces     INT NOT NULL CHECK (total_spaces 
> 0),
available_spaces INT NOT NULL,
CHECK (available_spaces >= 0 AND available_spaces 
<= total_spaces)
);
CREATE TABLE allocations (
allocation_id  SERIAL PRIMARY KEY,
student_number VARCHAR(20) NOT NULL,
room_id        INT NOT NULL REFERENCES 
hostel_rooms(room_id),
status         VARCHAR(10) NOT NULL DEFAULT 
'ALLOCATED'
CHECK (status IN ('ALLOCATED', 
'COMPLETE')),
allocated_at   TIMESTAMP NOT NULL DEFAULT NOW(),
checked_out_at TIMESTAMP
);
INSERT INTO hostel_rooms (room_name, total_spaces, 
available_spaces) VALUES
('A101', 4, 4),   -- several spaces
('B202', 3, 1),   -- one space left
('C303', 2, 0);   -- full
SELECT * FROM hostel_rooms ORDER BY room_id;
DO $$
DECLARE
r      RECORD;
v_msg  TEXT;
BEGIN
FOR r IN SELECT room_name, available_spaces FROM 
hostel_rooms ORDER BY room_id LOOP
IF r.available_spaces = 0 THEN
v_msg := 'FULL';
ELSIF r.available_spaces = 1 THEN
v_msg := 'has ONE space left';
ELSE
v_msg := 'has SEVERAL spaces (' || 
r.available_spaces || ')';
END IF;
RAISE NOTICE 'Room %: %', r.room_name, v_msg;
END LOOP;
END $$;
DO $$
DECLARE
v_day INT := 1;
BEGIN
WHILE v_day <= 3 LOOP
RAISE NOTICE 'Hostel inspection day %', v_day;
v_day := v_day + 1;
END LOOP;
FOR i IN 1..3 LOOP
RAISE NOTICE 'Room check number %', i;
END LOOP;
END $$;
CREATE OR REPLACE PROCEDURE 
allocate_room(p_student_number VARCHAR, p_room_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_available INT;
v_name      
VARCHAR(20);
BEGIN-- Validate input
IF p_student_number IS NULL OR 
TRIM(p_student_number) = '' THEN
RAISE EXCEPTION 'Student number cannot be 
blank';
END IF;-- Lock the room row so concurrent allocations cannot overbook
SELECT available_spaces, room_name
INTO v_available, v_name
FROM hostel_rooms
WHERE room_id = p_room_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Room % does not exist', 
p_room_id;
END IF;
IF v_available < 1 THEN
RAISE NOTICE 'Allocation REJECTED: room % is 
full (student %)', v_name, p_student_number;
RETURN;
END IF;
UPDATE hostel_rooms
SET available_spaces = available_spaces - 1
WHERE room_id = p_room_id;
INSERT INTO allocations (student_number, room_id)
VALUES (TRIM(p_student_number), p_room_id);
RAISE NOTICE 'Student % allocated to room %', 
p_student_number, v_name;
END $$;
CALL allocate_room('S2026001', 1);   -- valid (A101)
CALL allocate_room('S2026002', 1);   -- valid (A101)
CALL allocate_room('S2026003', 3);   -- rejected (C303 is full)
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id 
INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_status  VARCHAR(10);
v_room_id INT;
BEGIN
SELECT status, room_id
INTO v_status, v_room_id
FROM allocations
WHERE allocation_id = p_allocation_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Allocation % does not exist', 
p_allocation_id;
END IF;
IF v_status = 'COMPLETE' THEN
RAISE NOTICE 'Allocation % already checked out - no space released', p_allocation_id;
RETURN;
END IF;
UPDATE hostel_rooms
SET available_spaces = available_spaces + 1
WHERE room_id = v_room_id;
UPDATE allocations
SET status = 'COMPLETE',
checked_out_at = NOW()
WHERE allocation_id = p_allocation_id;
RAISE NOTICE 'Allocation % checked out - one space 
released', p_allocation_id;
END $$;
CALL check_out(1);   -- releases a space
CALL check_out(1);   -- second call: must not free another space
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
DO $$
DECLARE
cur_rooms CURSOR FOR
SELECT room_name, available_spaces
FROM hostel_rooms
WHERE available_spaces <= 1
ORDER BY room_id;
v_name  hostel_rooms.room_name%TYPE;
v_avail hostel_rooms.available_spaces%TYPE;
BEGIN
OPEN cur_rooms;
LOOP
FETCH cur_rooms INTO v_name, v_avail;
EXIT WHEN NOT FOUND;
RAISE NOTICE 'Room % is % (available spaces: 
%)',
v_name,
CASE WHEN v_avail = 0 THEN 'FULL' ELSE 
'NEARLY FULL' END,
v_avail;
END LOOP;
CLOSE cur_rooms;
END $$;
DO $$
BEGIN
CALL allocate_room('   ', 1);
EXCEPTION
WHEN raise_exception THEN
RAISE NOTICE 'Invalid input handled: %', 
SQLERRM;
END $$;
SELECT room_id, room_name, total_spaces, 
available_spaces
FROM hostel_rooms
ORDER BY room_id;
SELECT allocation_id, student_number, room_id, status, 
allocated_at, checked_out_at
FROM allocations
ORDER BY allocation_id;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS events;
CREATE TABLE events (
event_id        SERIAL PRIMARY KEY,
event_name      VARCHAR(100) NOT NULL UNIQUE,
total_seats     INT NOT NULL CHECK (total_seats > 0),
available_seats INT NOT NULL,
CHECK (available_seats >= 0 AND available_seats <= 
total_seats)
);
CREATE TABLE bookings (
booking_id     SERIAL PRIMARY KEY,
student_number VARCHAR(20) NOT NULL,
event_id       INT NOT NULL REFERENCES 
events(event_id),
seats_booked   INT NOT NULL CHECK (seats_booked > 
0),
status         VARCHAR(10) NOT NULL DEFAULT
'BOOKED'
CHECK (status IN ('BOOKED', 
'CANCELLED')),
booked_at      TIMESTAMP NOT NULL DEFAULT NOW(),
cancelled_at   TIMESTAMP
);
INSERT INTO events (event_name, total_seats, 
available_seats) VALUES
('Career Fair',    
100, 100),   -- plenty of seats
('Graduation Gala', 50,   5),   -- nearly full
('Tech Talk',       
30,   0);   -- full
SELECT * FROM events ORDER BY event_id;
DO $$
DECLARE
v_day INT := 1;
BEGIN
WHILE v_day <= 3 LOOP
RAISE NOTICE 'Booking reminder day %', v_day;
v_day := v_day + 1;
END LOOP;
FOR i IN 1..3 LOOP
RAISE NOTICE 'Entrance check number %', i;
END LOOP;
END $$;
DO $$
DECLARE
r     
RECORD;
v_msg TEXT;
BEGIN
FOR r IN SELECT event_name, available_seats FROM 
events ORDER BY event_id LOOP
IF r.available_seats = 0 THEN
v_msg := 'FULL';
ELSIF r.available_seats <= 10 THEN
v_msg := 'NEARLY FULL (' || 
r.available_seats || ' seats left)';
ELSE
v_msg := 'PLENTY of seats (' || 
r.available_seats || ')';
END IF;
RAISE NOTICE '%: %', r.event_name, v_msg;
END LOOP;
END $$;
CREATE OR REPLACE PROCEDURE 
book_seats(p_student_number VARCHAR, p_event_id INT, 
p_seats INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_available INT;
v_name      VARCHAR(100);
BEGIN-- Validate input
IF p_student_number IS NULL OR 
TRIM(p_student_number) = '' THEN
RAISE EXCEPTION 'Student number cannot be 
blank';
END IF;
IF p_seats IS NULL OR p_seats <= 0 THEN
RAISE EXCEPTION 'Invalid number of seats: % 
(must be at least 1)', p_seats;
END IF;
SELECT available_seats, event_name
INTO v_available, v_name
FROM events
WHERE event_id = p_event_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Event % does not exist', 
p_event_id;
END IF;
IF p_seats > v_available THEN
RAISE NOTICE 'Booking REJECTED: % requested % 
seats for "%" but only % remain',
p_student_number, p_seats, v_name, 
v_available;
RETURN;
END IF;
UPDATE events
SET available_seats = available_seats - p_seats
WHERE event_id = p_event_id;
INSERT INTO bookings (student_number, event_id, 
seats_booked)
VALUES (TRIM(p_student_number), p_event_id, 
p_seats);
RAISE NOTICE 'Booking recorded: % booked % seat(s) 
for "%"',
p_student_number, p_seats, v_name;
END $$;
CALL book_seats('S2026001', 1, 4);    -- valid: Career 
CALL book_seats('S2026002', 2, 2);    -- valid: 
CALL book_seats('S2026003', 2, 10);   -- rejected: only 3 seats remain
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;
CREATE OR REPLACE PROCEDURE 
cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
v_status   VARCHAR(10);
v_event_id INT;
v_seats    
INT;
BEGIN
SELECT status, event_id, seats_booked
INTO v_status, v_event_id, v_seats
FROM bookings
WHERE booking_id = p_booking_id
FOR UPDATE;
IF NOT FOUND THEN
RAISE EXCEPTION 'Booking % does not exist', 
p_booking_id;
END IF;
IF v_status = 'CANCELLED' THEN
RAISE NOTICE 'Booking % already cancelled - no 
seats released', p_booking_id;
RETURN;
END IF;
UPDATE events
SET available_seats = available_seats + v_seats
WHERE event_id = v_event_id;
UPDATE bookings
SET status = 'CANCELLED',
cancelled_at = NOW()
WHERE booking_id = p_booking_id;
RAISE NOTICE 'Booking % cancelled - % seat(s) 
released', p_booking_id, v_seats;
END $$;
CALL cancel_booking(1);   -- releases seats
CALL cancel_booking(1);   -- second call: must not release seats again
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;
DO $$
DECLARE
cur_events CURSOR FOR
SELECT event_name, available_seats
FROM events
WHERE available_seats <= 10
ORDER BY event_id;
v_name  events.event_name%TYPE;
v_seats events.available_seats%TYPE;
BEGIN
OPEN cur_events;
LOOP
FETCH cur_events INTO v_name, v_seats;
EXIT WHEN NOT FOUND;
RAISE NOTICE '% is % (seats left: %)',
v_name,
CASE WHEN v_seats = 0 THEN 'FULL' ELSE 
'NEARLY FULL' END,
v_seats;
END LOOP;
CLOSE cur_events;
END $$;
DO $$
BEGIN
CALL book_seats('S2026004', 1, 0);
EXCEPTION
WHEN raise_exception THEN
RAISE NOTICE 'Invalid input handled: %', 
SQLERRM;
END $$;
SELECT event_id, event_name, total_seats, 
available_seats
FROM events
ORDER BY event_id;
SELECT booking_id, student_number, event_id, 
seats_booked, status, booked_at, cancelled_at
FROM bookings
ORDER BY booking_id;
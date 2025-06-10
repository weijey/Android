CREATE TABLE Users (
    users_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- �û���ţ�������
    name VARCHAR(100),                               -- ����
    phone VARCHAR(20),                               -- �绰
    balance DECIMAL(10, 2),                          -- ���
    user_type VARCHAR(20),                           -- �û�����
    user_password VARCHAR(10)                        -- ����
);
CREATE TABLE Train (
    train_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ���α�ţ�������
    train_name VARCHAR(100),                          -- ��������
    standing_seats INT,                               -- վƱ����
    sleeper_seats INT,                                -- ����Ʊ����
    standing_seat_price DECIMAL(10, 2),               -- վƱ�۸�
    sleeper_seat_price DECIMAL(10, 2)                 -- ����Ʊ�۸�
);
CREATE TABLE Route (
    route_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ·�߱�ţ�������
    start_station VARCHAR(100),                       -- ���վ
    end_station VARCHAR(100),                         -- �յ�վ
    departure_time DATETIME,                          -- ����ʱ��
    arrival_time DATETIME                             -- ����ʱ��
);
CREATE TABLE Orders (
    order_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ������ţ�������
    start_station VARCHAR(100),                       -- ���վ
    end_station VARCHAR(100),                         -- �յ�վ
    departure_time DATETIME,                          -- ����ʱ��
    arrival_time DATETIME,                            -- ����ʱ��
    seat_number VARCHAR(10),                          -- ��λ��
    seat_type VARCHAR(10),                            -- ��λ����
    users_id INT,                                     -- �����û� (���)
    train_id INT,                                     -- �������� (���)
    FOREIGN KEY (users_id) REFERENCES Users(users_id),  -- ���Լ��
    FOREIGN KEY (train_id) REFERENCES Train(train_id)   -- ���Լ��
);
CREATE TABLE Ticket (
    ticket_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ��Ʊ��ţ�������
    order_id INT,                                     -- �������� (���)
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)  -- ���Լ��
);
CREATE TABLE Salesperson (
    salesperson_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ҵ��Ա��ţ�������
    name VARCHAR(100),                                      -- ����
    phone VARCHAR(20),                                      -- �绰
    password VARCHAR(100)                                   -- ����
);
CREATE TABLE SalesRecord (
    sales_record_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ���ۼ�¼��ţ�������
    order_id INT,                                            -- �������� (���)
    salesperson_id INT,                                      -- ����ҵ��Ա (���)
    sale_time DATETIME,                                      -- ����ʱ��
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),       -- ���Լ��
    FOREIGN KEY (salesperson_id) REFERENCES Salesperson(salesperson_id)  -- ���Լ��
);
CREATE TABLE TicketReturn (
    return_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ��Ʊ��ţ�������
    ticket_id INT,                                     -- ������Ʊ (���)
    return_time DATETIME,                              -- ��Ʊʱ��
    FOREIGN KEY (ticket_id) REFERENCES Ticket(ticket_id)  -- ���Լ��
);
CREATE TABLE TrainRoute (
    train_route_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- ����·�߱�ţ�������
    train_id INT,                                           -- �������� (���)
    route_id INT,                                           -- ����·�� (���)
    price DECIMAL(10, 2),                                   -- Ʊ��
    FOREIGN KEY (train_id) REFERENCES Train(train_id),       -- ���Լ��
    FOREIGN KEY (route_id) REFERENCES Route(route_id)        -- ���Լ��
);

--1.1 ����������������ʱ���³���ʣ����λ��
CREATE TRIGGER trg_UpdateAvailableSeatsOnSale
ON Orders
AFTER INSERT
AS
BEGIN
    DECLARE @seat_type VARCHAR(10);
    DECLARE @train_id INT;

    SELECT @seat_type = seat_type, @train_id = train_id
    FROM inserted;

    IF @seat_type = 'standing'
        UPDATE Train
        SET standing_seats = standing_seats - 1
        WHERE train_id = @train_id;
    ELSE IF @seat_type = 'sleeper'
        UPDATE Train
        SET sleeper_seats = sleeper_seats - 1
        WHERE train_id = @train_id;
END;
--2.2 ����������Ʊʱ���³���ʣ����λ��
CREATE TRIGGER trg_UpdateAvailableSeatsOnReturn
ON TicketReturn
AFTER INSERT
AS
BEGIN
    DECLARE @ticket_id INT;
    DECLARE @seat_type VARCHAR(10);
    DECLARE @train_id INT;

    SELECT @ticket_id = ticket_id FROM inserted;

    SELECT @seat_type = o.seat_type, @train_id = o.train_id
    FROM Orders o
    JOIN Ticket t ON o.order_id = t.order_id
    WHERE t.ticket_id = @ticket_id;

    IF @seat_type = 'standing'
        UPDATE Train
        SET standing_seats = standing_seats + 1
        WHERE train_id = @train_id;
    ELSE IF @seat_type = 'sleeper'
        UPDATE Train
        SET sleeper_seats = sleeper_seats + 1
        WHERE train_id = @train_id;
END;
--2.3 ����������������ʱ�����û����
CREATE TRIGGER trg_UpdateUserBalanceOnOrder
ON Orders
AFTER INSERT
AS
BEGIN
    DECLARE @users_id INT;
    DECLARE @seat_type VARCHAR(10);
    DECLARE @train_id INT;
    DECLARE @ticket_price DECIMAL(10, 2);

    SELECT @users_id = users_id, @seat_type = seat_type, @train_id = train_id
    FROM inserted;

    IF @seat_type = 'standing'
        SELECT @ticket_price = standing_seat_price
        FROM Train
        WHERE train_id = @train_id;
    ELSE IF @seat_type = 'sleeper'
        SELECT @ticket_price = sleeper_seat_price
        FROM Train
        WHERE train_id = @train_id;

    UPDATE Users
    SET balance = balance - @ticket_price
    WHERE users_id = @users_id;
END;
--2.4 ����������Ʊʱ�����û����
CREATE TRIGGER trg_UpdateUserBalanceOnReturn
ON TicketReturn
AFTER INSERT
AS
BEGIN
    DECLARE @ticket_id INT;
    DECLARE @seat_type VARCHAR(10);
    DECLARE @train_id INT;
    DECLARE @refund_amount DECIMAL(10, 2);
    DECLARE @users_id INT;

    -- ��ȡ��Ʊ�� ticket_id
    SELECT @ticket_id = ticket_id FROM inserted;

    -- ��ȡ������ seat_type �� train_id
    SELECT @seat_type = o.seat_type, @train_id = o.train_id, @users_id = o.users_id
    FROM Orders o
    JOIN Ticket t ON o.order_id = t.order_id
    WHERE t.ticket_id = @ticket_id;

    -- ���� seat_type �� train_id ��ȡƱ��
    IF @seat_type = 'standing'
        SELECT @refund_amount = standing_seat_price
        FROM Train
        WHERE train_id = @train_id;
    ELSE IF @seat_type = 'sleeper'
        SELECT @refund_amount = sleeper_seat_price
        FROM Train
        WHERE train_id = @train_id;

    -- �����û����
    UPDATE Users
    SET balance = balance + @refund_amount
    WHERE users_id = @users_id;
END;
--3.1 Train ���ʼ����
-- 3.1 Train ���ʼ����
INSERT INTO Train (train_name, standing_seats, sleeper_seats, standing_seat_price, sleeper_seat_price)
VALUES
('G101', 600, 200, 200.00, 500.00),
('D202', 450, 150, 150.00, 350.00),
('Z303', 300, 300, 120.00, 280.00),
('K404', 500, 250, 180.00, 400.00),
('T505', 400, 200, 160.00, 320.00),
('C606', 550, 180, 190.00, 380.00);
--3.2 Route ���ʼ����
INSERT INTO Route (route_id, start_station, end_station, departure_time, arrival_time)
VALUES
(1, '����', '�Ϻ�', '2023-10-01 08:00:00', '2023-10-01 18:00:00'),
(2, '�Ϻ�', '����', '2023-10-02 09:00:00', '2023-10-02 21:00:00'),
(3, '����', '����', '2023-10-03 10:00:00', '2023-10-03 12:00:00'),
(4, '����', '����', '2023-10-04 11:00:00', '2023-10-04 23:00:00'),
(5, '����', '����', '2023-10-05 07:00:00', '2023-10-05 17:00:00'),
(6, '�Ϻ�', '����', '2023-10-06 08:00:00', '2023-10-06 19:00:00');
--3.3 TrainRoute ���ʼ����
INSERT INTO TrainRoute (train_id, route_id, price)
VALUES
(1, 1, 200.00),
(2, 2, 150.00),
(3, 3, 120.00),
(4, 4, 180.00),
(5, 5, 160.00),
(6, 6, 190.00);
--3.4 Users ���ʼ����
INSERT INTO TrainRoute (train_id, route_id, price)
VALUES
(1, 1, 200.00),
(2, 2, 150.00),
(3, 3, 120.00),
(4, 4, 180.00),
(5, 5, 160.00),
(6, 6, 190.00);
--3.5 Salesperson ���ʼ����
INSERT INTO Salesperson (name, phone, password)
VALUES
('ҵ��Ա1', '13800138000', 'admin1'),
('ҵ��Ա2', '13900139000', 'admin2');
--routeshuju
INSERT INTO Route (start_station, end_station, departure_time, arrival_time)
VALUES
('����', '�Ϻ�', '2023-10-01 08:00:00', '2023-10-01 18:00:00'),
('�Ϻ�', '����', '2023-10-02 09:00:00', '2023-10-02 21:00:00'),
('����', '����', '2023-10-03 10:00:00', '2023-10-03 12:00:00'),
('����', '����', '2023-10-04 11:00:00', '2023-10-04 23:00:00'),
('����', '����', '2023-10-05 07:00:00', '2023-10-05 17:00:00'),
('�Ϻ�', '����', '2023-10-06 08:00:00', '2023-10-06 19:00:00');

--1. ���� user_type �еĳ���
ALTER TABLE Users
ALTER COLUMN user_type VARCHAR(20);
ALTER TABLE Orders
ADD total_price DECIMAL(10, 2);
ALTER TABLE Users
ALTER COLUMN balance DECIMAL(10, 2) NOT NULL;

-- �� balance ��Ϊ NULL ���и���Ϊ 0.00
UPDATE Users
SET balance = 0.00
WHERE balance IS NULL;

--���train
ALTER TABLE Train
ADD start_station VARCHAR(255),
    end_station VARCHAR(255),
    departure_time DATETIME,
    arrival_time DATETIME;
--��ӵ�salesrecord
ALTER TABLE SalesRecord
ADD remaining_seats INT;  -- ����ʱ��ʣ����λ��

---��ӵ�ticket return
ALTER TABLE TicketReturn
ADD remaining_seats INT;  -- ��Ʊʱ��ʣ����λ��

--���train
-- Ϊ train_id = 1 �������
UPDATE Train
SET start_station = '����',
    end_station = '�Ϻ�',
    departure_time = '2023-10-01 08:00:00',
    arrival_time = '2023-10-01 18:00:00'
WHERE train_id = 1;

-- Ϊ train_id = 2 �������
UPDATE Train
SET start_station = '�Ϻ�',
    end_station = '����',
    departure_time = '2023-10-02 09:00:00',
    arrival_time = '2023-10-02 21:00:00'
WHERE train_id = 2;

-- Ϊ train_id = 3 �������
UPDATE Train
SET start_station = '����',
    end_station = '����',
    departure_time = '2023-10-03 10:00:00',
    arrival_time = '2023-10-03 12:00:00'
WHERE train_id = 3;

-- Ϊ train_id = 4 �������
UPDATE Train
SET start_station = '����',
    end_station = '����',
    departure_time = '2023-10-04 11:00:00',
    arrival_time = '2023-10-04 23:00:00'
WHERE train_id = 4;

-- Ϊ train_id = 5 �������
UPDATE Train
SET start_station = '����',
    end_station = '����',
    departure_time = '2023-10-05 07:00:00',
    arrival_time = '2023-10-05 17:00:00'
WHERE train_id = 5;

-- Ϊ train_id = 6 �������
UPDATE Train
SET start_station = '�Ϻ�',
    end_station = '����',
    departure_time = '2023-10-06 08:00:00',
    arrival_time = '2023-10-06 19:00:00'
WHERE train_id = 6;


ALTER TABLE SalesRecord
ADD total_price DECIMAL(10, 2);  -- ���۽��


ALTER TABLE Ticket
DROP CONSTRAINT FK__Ticket__order_id__412EB0B6;

ALTER TABLE Ticket
ADD CONSTRAINT FK__Ticket__order_id__412EB0B6
FOREIGN KEY (order_id) REFERENCES Orders(order_id)
ON DELETE CASCADE;
ALTER TABLE SalesRecord
ADD total_price DECIMAL(10, 2);


--����������

-- ���붩������
INSERT INTO Orders (start_station, end_station, departure_time, arrival_time, seat_number, seat_type, users_id, train_id, total_price)
VALUES
('����', '�Ϻ�', '2023-10-01 08:00:00', '2023-10-01 18:00:00', 'A1', 'standing', 1, 1, 200.00),
('�Ϻ�', '����', '2023-10-02 09:00:00', '2023-10-02 21:00:00', 'B2', 'sleeper', 2, 2, 350.00),
('����', '����', '2023-10-03 10:00:00', '2023-10-03 12:00:00', 'C3', 'standing', 3, 3, 120.00),
('����', '����', '2023-10-04 11:00:00', '2023-10-04 23:00:00', 'D4', 'sleeper', 4, 4, 400.00),
('����', '����', '2023-10-05 07:00:00', '2023-10-05 17:00:00', 'E5', 'standing', 1, 5, 160.00),
('�Ϻ�', '����', '2023-10-06 08:00:00', '2023-10-06 19:00:00', 'F6', 'sleeper', 2, 6, 380.00);
--�޸�password�ĳ���
ALTER TABLE Users
ALTER COLUMN user_password VARCHAR(100);

--�ٴ��������
-- �����û�����
INSERT INTO Users (name, phone, balance, user_type, user_password)
VALUES
('����', '13812345678', 1000.00, 'user', '123456'),
('����', '13987654321', 500.00, 'user', '654321'),
('����', '13611112222', 2000.00, 'user', 'password123'),
('����', '13733334444', 1500.00, 'user', 'qwerty'),
('ҵ��ԱA', '13800138000', 0.00, 'salesperson', 'admin1'),
('ҵ��ԱB', '13900139000', 0.00, 'salesperson', 'admin2');
CREATE TABLE Users (
    users_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 用户编号，自增列
    name VARCHAR(100),                               -- 姓名
    phone VARCHAR(20),                               -- 电话
    balance DECIMAL(10, 2),                          -- 余额
    user_type VARCHAR(20),                           -- 用户类型
    user_password VARCHAR(10)                        -- 密码
);
CREATE TABLE Train (
    train_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 车次编号，自增列
    train_name VARCHAR(100),                          -- 车次名称
    standing_seats INT,                               -- 站票数量
    sleeper_seats INT,                                -- 卧铺票数量
    standing_seat_price DECIMAL(10, 2),               -- 站票价格
    sleeper_seat_price DECIMAL(10, 2)                 -- 卧铺票价格
);
CREATE TABLE Route (
    route_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 路线编号，自增列
    start_station VARCHAR(100),                       -- 起点站
    end_station VARCHAR(100),                         -- 终点站
    departure_time DATETIME,                          -- 发车时间
    arrival_time DATETIME                             -- 到达时间
);
CREATE TABLE Orders (
    order_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 订单编号，自增列
    start_station VARCHAR(100),                       -- 起点站
    end_station VARCHAR(100),                         -- 终点站
    departure_time DATETIME,                          -- 发车时间
    arrival_time DATETIME,                            -- 到达时间
    seat_number VARCHAR(10),                          -- 座位号
    seat_type VARCHAR(10),                            -- 座位类型
    users_id INT,                                     -- 关联用户 (外键)
    train_id INT,                                     -- 关联车次 (外键)
    FOREIGN KEY (users_id) REFERENCES Users(users_id),  -- 外键约束
    FOREIGN KEY (train_id) REFERENCES Train(train_id)   -- 外键约束
);
CREATE TABLE Ticket (
    ticket_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 车票编号，自增列
    order_id INT,                                     -- 关联订单 (外键)
    FOREIGN KEY (order_id) REFERENCES Orders(order_id)  -- 外键约束
);
CREATE TABLE Salesperson (
    salesperson_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 业务员编号，自增列
    name VARCHAR(100),                                      -- 姓名
    phone VARCHAR(20),                                      -- 电话
    password VARCHAR(100)                                   -- 密码
);
CREATE TABLE SalesRecord (
    sales_record_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 销售记录编号，自增列
    order_id INT,                                            -- 关联订单 (外键)
    salesperson_id INT,                                      -- 关联业务员 (外键)
    sale_time DATETIME,                                      -- 销售时间
    FOREIGN KEY (order_id) REFERENCES Orders(order_id),       -- 外键约束
    FOREIGN KEY (salesperson_id) REFERENCES Salesperson(salesperson_id)  -- 外键约束
);
CREATE TABLE TicketReturn (
    return_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 退票编号，自增列
    ticket_id INT,                                     -- 关联车票 (外键)
    return_time DATETIME,                              -- 退票时间
    FOREIGN KEY (ticket_id) REFERENCES Ticket(ticket_id)  -- 外键约束
);
CREATE TABLE TrainRoute (
    train_route_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,  -- 车次路线编号，自增列
    train_id INT,                                           -- 关联车次 (外键)
    route_id INT,                                           -- 关联路线 (外键)
    price DECIMAL(10, 2),                                   -- 票价
    FOREIGN KEY (train_id) REFERENCES Train(train_id),       -- 外键约束
    FOREIGN KEY (route_id) REFERENCES Route(route_id)        -- 外键约束
);

--1.1 触发器：订单创建时更新车次剩余座位数
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
--2.2 触发器：退票时更新车次剩余座位数
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
--2.3 触发器：订单创建时更新用户余额
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
--2.4 触发器：退票时更新用户余额
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

    -- 获取退票的 ticket_id
    SELECT @ticket_id = ticket_id FROM inserted;

    -- 获取订单的 seat_type 和 train_id
    SELECT @seat_type = o.seat_type, @train_id = o.train_id, @users_id = o.users_id
    FROM Orders o
    JOIN Ticket t ON o.order_id = t.order_id
    WHERE t.ticket_id = @ticket_id;

    -- 根据 seat_type 和 train_id 获取票价
    IF @seat_type = 'standing'
        SELECT @refund_amount = standing_seat_price
        FROM Train
        WHERE train_id = @train_id;
    ELSE IF @seat_type = 'sleeper'
        SELECT @refund_amount = sleeper_seat_price
        FROM Train
        WHERE train_id = @train_id;

    -- 更新用户余额
    UPDATE Users
    SET balance = balance + @refund_amount
    WHERE users_id = @users_id;
END;
--3.1 Train 表初始数据
-- 3.1 Train 表初始数据
INSERT INTO Train (train_name, standing_seats, sleeper_seats, standing_seat_price, sleeper_seat_price)
VALUES
('G101', 600, 200, 200.00, 500.00),
('D202', 450, 150, 150.00, 350.00),
('Z303', 300, 300, 120.00, 280.00),
('K404', 500, 250, 180.00, 400.00),
('T505', 400, 200, 160.00, 320.00),
('C606', 550, 180, 190.00, 380.00);
--3.2 Route 表初始数据
INSERT INTO Route (route_id, start_station, end_station, departure_time, arrival_time)
VALUES
(1, '北京', '上海', '2023-10-01 08:00:00', '2023-10-01 18:00:00'),
(2, '上海', '广州', '2023-10-02 09:00:00', '2023-10-02 21:00:00'),
(3, '广州', '深圳', '2023-10-03 10:00:00', '2023-10-03 12:00:00'),
(4, '深圳', '北京', '2023-10-04 11:00:00', '2023-10-04 23:00:00'),
(5, '北京', '广州', '2023-10-05 07:00:00', '2023-10-05 17:00:00'),
(6, '上海', '深圳', '2023-10-06 08:00:00', '2023-10-06 19:00:00');
--3.3 TrainRoute 表初始数据
INSERT INTO TrainRoute (train_id, route_id, price)
VALUES
(1, 1, 200.00),
(2, 2, 150.00),
(3, 3, 120.00),
(4, 4, 180.00),
(5, 5, 160.00),
(6, 6, 190.00);
--3.4 Users 表初始数据
INSERT INTO TrainRoute (train_id, route_id, price)
VALUES
(1, 1, 200.00),
(2, 2, 150.00),
(3, 3, 120.00),
(4, 4, 180.00),
(5, 5, 160.00),
(6, 6, 190.00);
--3.5 Salesperson 表初始数据
INSERT INTO Salesperson (name, phone, password)
VALUES
('业务员1', '13800138000', 'admin1'),
('业务员2', '13900139000', 'admin2');
--routeshuju
INSERT INTO Route (start_station, end_station, departure_time, arrival_time)
VALUES
('北京', '上海', '2023-10-01 08:00:00', '2023-10-01 18:00:00'),
('上海', '广州', '2023-10-02 09:00:00', '2023-10-02 21:00:00'),
('广州', '深圳', '2023-10-03 10:00:00', '2023-10-03 12:00:00'),
('深圳', '北京', '2023-10-04 11:00:00', '2023-10-04 23:00:00'),
('北京', '广州', '2023-10-05 07:00:00', '2023-10-05 17:00:00'),
('上海', '深圳', '2023-10-06 08:00:00', '2023-10-06 19:00:00');

--1. 增加 user_type 列的长度
ALTER TABLE Users
ALTER COLUMN user_type VARCHAR(20);
ALTER TABLE Orders
ADD total_price DECIMAL(10, 2);
ALTER TABLE Users
ALTER COLUMN balance DECIMAL(10, 2) NOT NULL;

-- 将 balance 列为 NULL 的行更新为 0.00
UPDATE Users
SET balance = 0.00
WHERE balance IS NULL;

--添加train
ALTER TABLE Train
ADD start_station VARCHAR(255),
    end_station VARCHAR(255),
    departure_time DATETIME,
    arrival_time DATETIME;
--添加到salesrecord
ALTER TABLE SalesRecord
ADD remaining_seats INT;  -- 销售时的剩余座位数

---添加到ticket return
ALTER TABLE TicketReturn
ADD remaining_seats INT;  -- 退票时的剩余座位数

--添加train
-- 为 train_id = 1 填充数据
UPDATE Train
SET start_station = '北京',
    end_station = '上海',
    departure_time = '2023-10-01 08:00:00',
    arrival_time = '2023-10-01 18:00:00'
WHERE train_id = 1;

-- 为 train_id = 2 填充数据
UPDATE Train
SET start_station = '上海',
    end_station = '广州',
    departure_time = '2023-10-02 09:00:00',
    arrival_time = '2023-10-02 21:00:00'
WHERE train_id = 2;

-- 为 train_id = 3 填充数据
UPDATE Train
SET start_station = '广州',
    end_station = '深圳',
    departure_time = '2023-10-03 10:00:00',
    arrival_time = '2023-10-03 12:00:00'
WHERE train_id = 3;

-- 为 train_id = 4 填充数据
UPDATE Train
SET start_station = '深圳',
    end_station = '北京',
    departure_time = '2023-10-04 11:00:00',
    arrival_time = '2023-10-04 23:00:00'
WHERE train_id = 4;

-- 为 train_id = 5 填充数据
UPDATE Train
SET start_station = '北京',
    end_station = '广州',
    departure_time = '2023-10-05 07:00:00',
    arrival_time = '2023-10-05 17:00:00'
WHERE train_id = 5;

-- 为 train_id = 6 填充数据
UPDATE Train
SET start_station = '上海',
    end_station = '深圳',
    departure_time = '2023-10-06 08:00:00',
    arrival_time = '2023-10-06 19:00:00'
WHERE train_id = 6;


ALTER TABLE SalesRecord
ADD total_price DECIMAL(10, 2);  -- 销售金额


ALTER TABLE Ticket
DROP CONSTRAINT FK__Ticket__order_id__412EB0B6;

ALTER TABLE Ticket
ADD CONSTRAINT FK__Ticket__order_id__412EB0B6
FOREIGN KEY (order_id) REFERENCES Orders(order_id)
ON DELETE CASCADE;
ALTER TABLE SalesRecord
ADD total_price DECIMAL(10, 2);


--插入新数据

-- 插入订单数据
INSERT INTO Orders (start_station, end_station, departure_time, arrival_time, seat_number, seat_type, users_id, train_id, total_price)
VALUES
('北京', '上海', '2023-10-01 08:00:00', '2023-10-01 18:00:00', 'A1', 'standing', 1, 1, 200.00),
('上海', '广州', '2023-10-02 09:00:00', '2023-10-02 21:00:00', 'B2', 'sleeper', 2, 2, 350.00),
('广州', '深圳', '2023-10-03 10:00:00', '2023-10-03 12:00:00', 'C3', 'standing', 3, 3, 120.00),
('深圳', '北京', '2023-10-04 11:00:00', '2023-10-04 23:00:00', 'D4', 'sleeper', 4, 4, 400.00),
('北京', '广州', '2023-10-05 07:00:00', '2023-10-05 17:00:00', 'E5', 'standing', 1, 5, 160.00),
('上海', '深圳', '2023-10-06 08:00:00', '2023-10-06 19:00:00', 'F6', 'sleeper', 2, 6, 380.00);
--修改password的长度
ALTER TABLE Users
ALTER COLUMN user_password VARCHAR(100);

--再次添加数据
-- 插入用户数据
INSERT INTO Users (name, phone, balance, user_type, user_password)
VALUES
('张三', '13812345678', 1000.00, 'user', '123456'),
('李四', '13987654321', 500.00, 'user', '654321'),
('王五', '13611112222', 2000.00, 'user', 'password123'),
('赵六', '13733334444', 1500.00, 'user', 'qwerty'),
('业务员A', '13800138000', 0.00, 'salesperson', 'admin1'),
('业务员B', '13900139000', 0.00, 'salesperson', 'admin2');
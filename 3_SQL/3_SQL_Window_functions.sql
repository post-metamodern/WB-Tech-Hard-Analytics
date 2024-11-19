-- Часть 1

-- Расчёт с использованием функций min max (без оконных функций).

-- В подзапросах name_highest_paid_employee_industry/name_lowest_paid_employee_industry:
-- Нахожу имя человека с наибольшей/наименьшей зарплату в каждой индустрии (where in).
--
-- В основном запросе:
-- Объединяю таблицу с зарплатами и таблицу подзапроса с именем искомого человека.

with name_highest_paid_employee_industry as (select first_name, salary, industry
                                             from temporary_window_f.salary
                                             where (salary, industry) in (select max(salary), industry
                                                                          from temporary_window_f.salary
                                                                          group by industry))

select salary.first_name
     , salary.last_name
     , salary.salary
     , salary.industry
     , name.first_name as name_highest_sal
from temporary_window_f.salary as salary
         join name_highest_paid_employee_industry as name
              using (industry)
order by name.industry
limit 100;


with name_lowest_paid_employee_industry as (select first_name, salary, industry
                                            from temporary_window_f.salary
                                            where (salary, industry) in (select min(salary), industry
                                                                         from temporary_window_f.salary
                                                                         group by industry))

select salary.first_name
     , salary.last_name
     , salary.salary
     , salary.industry
     , name.first_name as name_lowest_sal
from temporary_window_f.salary as salary
         join name_lowest_paid_employee_industry as name
              using (industry)
order by name.industry
limit 100;


-- Расчёт с использованием функции смещения first/last value.

-- В основном запросе:
-- С помощью оконной функции смещения first_value/last_value
-- нахожу первое/последние имя по сортировки зарплаты по возрастанию
-- среди определённой индустрии.

select first_name
     , last_name
     , salary
     , industry
     , first_value(first_name) over (partition by industry order by salary) as name_lowest_sal
from temporary_window_f.salary
limit 100;


select first_name
     , last_name
     , salary
     , industry
     , last_value(first_name)
       over (partition by industry order by salary
           rows between unbounded preceding and unbounded following
           ) as name_higest_sal
from temporary_window_f.salary
limit 100;



-- Часть 2

-- 1.

-- Соблюдая условия задач, называю во всех решениях итоговые колонки КАПСОМ.

-- Решение c оконной агрегирующей функцией.

-- В основном запросе:
-- Объединяю таблицы с информацией о товарах, продажах и магазинах.
-- Оставляю информацию только за 2016-01-02 число.
-- Нахожу сумму количества продаж товаров (сумму проданных товаров в штуках) у каждого магазина.
-- Нахожу сумму произведений цены товаров на их проданное количество (сумму проданных товаров в рублях) у каждого магазина.

select distinct shopnumber                                      as SHOPNUMBER
              , city                                            as CITY
              , address                                         as ADDRESS
              , sum(qty) over (partition by shopnumber)         as SUM_QTY
              , sum(price * qty) over (partition by shopnumber) as SUM_QTY_PRICE
from temporary_window_f.goods
         join temporary_window_f.sales using (id_good)
         join temporary_window_f.shops using (shopnumber)
where to_date(date, 'dd-mm-yyyy') in ('2016-01-02')
limit 100;


-- Пример возможного решения без оконных функций, с подзапросами.

with sum_qty_shopnumber as (select sum(qty) as SUM_QTY, shopnumber
                            from temporary_window_f.goods
                                     join temporary_window_f.sales using (id_good)
                            where to_date(date, 'dd-mm-yyyy') in ('2016-01-02')
                            group by shopnumber),

     sum_qty_price_shopnumber as (select shopnumber, sum(sum_price * SUM_QTY) as SUM_QTY_PRICE
                                  from (select id_good, sum(price) as sum_price, sum(qty) as SUM_QTY, shopnumber
                                        from temporary_window_f.goods
                                                 join temporary_window_f.sales using (id_good)
                                        where to_date(date, 'dd-mm-yyyy') in ('2016-01-02')
                                        group by id_good, shopnumber) as sum_price_qty_idgood
                                  group by shopnumber)

select shopnumber as SHOPNUMBER, city as CITY, address as ADDRESS, SUM_QTY, SUM_QTY_PRICE
from sum_qty_shopnumber
         join temporary_window_f.shops using (shopnumber)
         join sum_qty_price_shopnumber using (shopnumber)
limit 100;



-- 2.

-- Так же как и во всех других решениях "DATE_" я подразумеваю опечаткой и называю колонки "DATE".

-- Задание можно интерпретировать по-разному. Я подготовил 3 варианта решения:


-- а) Вариант с долей от суммарных продаж по городу на момент конкретного дня (суммируются стоимости покупок за все прошедшие дни)

-- В подзапросе sales_total_city_date:
-- Объединяю таблицы с информацией о товарах, продажах и магазинах.
-- Оставляю информацию о товарах направления ЧИСТОТА.
-- Нахожу сумму продаж по каждому городу в конкретную дату.
--
-- В оснвоном запросе:
-- Вычисляю процент суммы продаж по каждому городу в конкретную дату
-- от суммы продаж по всем городам на время текущего (по данным) дня.

with sales_total_city_date as
         (SELECT date                      AS DATE
               , city                      AS CITY
               , sum(qty * price)::decimal as sales_total
          from temporary_window_f.goods
                   join temporary_window_f.sales using (id_good)
                   join temporary_window_f.shops using (shopnumber)
          where category = 'ЧИСТОТА'
          group by DATE, CITY
          order by DATE)

select DATE
     , CITY
     , round(sales_total / sum(sales_total) over (order by date) * 100, 2) as SUM_SALES_REL
from sales_total_city_date
limit 100;


-- б) Вариант с долей от суммарных продаж по городу за конкретный день (стоимости покупок за все прошедшие дни не суммируются)

with sales_total_city_date as
         (SELECT date                      AS DATE
               , city                      AS CITY
               , SUM(qty * price)::decimal as sales_total
          from temporary_window_f.goods
                   join temporary_window_f.sales using (id_good)
                   join temporary_window_f.shops using (shopnumber)
          where category = 'ЧИСТОТА'
          group by DATE, CITY
          order by DATE)

select DATE
     , CITY
     , round(sales_total / sum(sales_total) over (partition by date) * 100, 2) as SUM_SALES_REL
from sales_total_city_date
limit 100;


-- в) Вариант с долей продаж за день от суммы стоимости покупок за все прошедшие дни

with sales_total_city_date as
         (SELECT date                      AS DATE
               , city                      AS CITY
               , SUM(qty * price)::decimal as sales_total
          from temporary_window_f.goods
                   join temporary_window_f.sales using (id_good)
                   join temporary_window_f.shops using (shopnumber)
          where category = 'ЧИСТОТА'
          group by DATE, CITY
          order by DATE)

select DATE
     , CITY
     , round(sum(sales_total) over (partition by date) / sum(sales_total) over (order by date) * 100,
             2) as SUM_SALES_REL
from sales_total_city_date
limit 100;



-- 3.

-- В подзапросе numbering_products_store:
-- С помощью оконной ранжирующей функции dense_rank
-- нумерую товары в зависимости от количества проданного товара (от большего к меньшему)
-- в каждом магазине за каждую дату.
-- (Я использовал dense_rank, чтобы не потерять никакие товары, по логике подходящие в задаче)
--
-- В основном запросе:
-- Оставляю только те товары, которые находятся на позициях 1, 2 и 3 (топ-3)
-- по продажам в штуках в каждом магазине в каждую дату.

select DATE, SHOPNUMBER, ID_GOOD
from (select date                                                        as DATE
           , shopnumber                                                  as SHOPNUMBER
           , id_good                                                     as ID_GOOD
           , dense_rank()
             over (partition by date, shopnumber order by sum(qty) desc) as numbering_according_number_orders
      from temporary_window_f.sales
      group by date, shopnumber, id_good) as numbering_products_store
where numbering_according_number_orders in (1, 2, 3)
limit 100;



-- 4.

-- В подзапросе sales_with_amount:
-- Объединяю таблицы с информацией о товарах, продажах и магазинах.
-- Оставляю данные только по городу Санкт-Петербург.
-- Нахожу сумму продаж по каждому товарному направлению магазина в конкретную дату.
--
-- В основном запросе:
-- С помощью оконной функции смещения lag нахожу
-- значения суммы продаж в рублях за предыдущую дату для каждого магазина и товарного направления
-- С помощью функции coalesce заменяю пустые значения, явно указывая, что предыдущей даты заказа нет.

with sales_with_amount as (select date
                                , shopnumber
                                , category
                                , sum(qty * price) as sales_amount
                           from temporary_window_f.sales
                                    join temporary_window_f.goods using (id_good)
                                    join temporary_window_f.shops using (shopnumber)
                           where city = 'СПб'
                           group by date, shopnumber, category)

select date                         as date
     , shopnumber                   as shopnumber
     , category                     as category
     , coalesce(lag(sales_amount) over
    (partition by shopnumber, category order by date)::varchar
    , 'нет предыдущей даты заказа') as prev_sales
from sales_with_amount
order by shopnumber, date, category
limit 100;



-- Часть 3

-- Создаю таблицу, указывая схему и название.
-- Указываю требуемое название колонок (разделяю searchid, userid, devicetype и deviceid нижним подчёркиванием)
-- Устанавливаю SERIAL PRIMARY KEY для search_id
-- с целью создания уникальной последовательности чисел и устанавливаю колонку как первичный ключ.
-- Определяю типы у других колонок в таблице.
--
-- С помощью INSERT INTO передаю в колонки значения

create table temporary_window_f.query
(
    search_id   serial primary key,
    year        int,
    month       int,
    day         int,
    user_id     int,
    ts          bigint,
    device_type varchar,
    device_id   varchar,
    query       text
);

insert into temporary_window_f.query (year, month, day, user_id, ts, device_type, device_id, query)
values (2024, 11, 5, 1, 1730764810, 'ipad', '202400', 'п'),
       (2024, 11, 5, 1, 1730764820, 'ipad', '202400', 'пу'),
       (2024, 11, 5, 1, 1730764830, 'ipad', '202400', 'пух'),
       (2024, 11, 5, 1, 1730764840, 'ipad', '202400', 'пухов'),
       (2024, 11, 5, 1, 1730764850, 'ipad', '202400', 'пуховик'),
       (2024, 11, 5, 1, 1730764860, 'ipad', '202400', 'пуховик му'),
       (2024, 11, 5, 1, 1730764870, 'ipad', '202400', 'пуховик мужской'),
       (2024, 11, 5, 2, 1730768420, 'macbook', '3000', 'п'),
       (2024, 11, 5, 2, 1730768430, 'macbook', '3000', 'по'),
       (2024, 11, 5, 2, 1730768440, 'macbook', '3000', 'под'),
       (2024, 11, 5, 2, 1730768450, 'macbook', '3000', 'подар'),
       (2024, 11, 5, 2, 1730768460, 'macbook', '3000', 'подарок'),
       (2024, 11, 5, 2, 1730768470, 'macbook', '3000', 'подарок маме'),
       (2024, 11, 5, 3, 1730793623, 'android', '20001111', 'тел'),
       (2024, 11, 5, 3, 1730794635, 'android', '20001111', 'телев'),
       (2024, 11, 5, 3, 1730795654, 'android', '20001111', 'телевизор'),
       (2024, 11, 5, 3, 1730795655, 'android', '20001111', 'телевизор цветной'),
       (2024, 11, 5, 3, 1730795720, 'android', '20001111', 'телевиз'),
       (2024, 11, 5, 3, 1730817999, 'android', '20001111', 'телевизор черн'),
       (2024, 11, 5, 3, 1730818733, 'android', '20001111', 'телевизор черно-белый'),
       (2024, 11, 5, 4, 1730819800, 'apple', '1', 'дил'),
       (2024, 11, 5, 5, 1730819812, 'potato', '99999', 'зар'),
       (2024, 11, 5, 5, 1730819813, 'potato', '99999', 'зарядка'),
       (2024, 11, 5, 5, 1730819814, 'potato', '99999', 'зарядка на'),
       (2024, 11, 5, 5, 1730819815, 'potato', '99999', 'зарядка на карт'),
       (2024, 11, 5, 5, 1730819816, 'potato', '99999', 'зарядка на картошку быстрая');



-- В поздапросе following_time_search:
-- С помощью оконных функций смещения lead нахожу время и название следующего поиска.
--
-- В подзапросе setting_is_final_categories:
-- Устанавливаю категории в колонку is_final по условиям задачи ("Если пользователь вбил запрос...")
--
-- В основном запросе:
-- Объединяю таблицы подзапроса setting_is_final_categories и главной таблицы query, для вывода всех колонок.
-- Фильтрую поиски с is_final = 1 или 2, за 5 ноября 2024 года, которые были сделаны с андройда

with following_time_search as (select search_id
                                    , ts
                                    , query
                                    , lead(ts) over (partition by user_id, device_type, device_id order by ts) as next_ts
                                    , lead(query)
                                      over (partition by user_id, device_type, device_id order by ts)          as next_query
                               from temporary_window_f.query),
     setting_is_final_categories as (select search_id
                                          , query
                                          , case
                                                when next_ts is null then 1
                                                when next_ts - ts > 180 then 1
                                                when next_query is not null and length(next_query) < length(query) and
                                                     next_ts - ts > 60 then 2
                                                else 0
             end as is_final
                                     from following_time_search)

select search_id
     , year
     , month
     , day
     , user_id
     , ts
     , device_type
     , device_id
     , temporary_window_f.query.query
     , is_final
from setting_is_final_categories
         join temporary_window_f.query using (search_id)
where year = 2024
  and month = 11
  and day = 5
  and device_type = 'android'
  and is_final in (1, 2)
limit 100;
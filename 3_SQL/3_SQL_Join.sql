-- Часть 1
-- Набор данных для выполнения заданий (1-3 задачи):
--
-- customers_new_3.csv
--
-- orders_new_3.csv
--
-- 1. Найти клиента с самым долгим временем ожидания между заказом и доставкой.
-- Для этой задачи у вас есть таблицы "Customers", "Orders"


-- По определению Shipment Date - это конкретная дата, когда заказ отправляется со склада перевозчику (посреднику),
-- а Delivery Date - фактическая дата, когда заказ будет доставлен клиенту.
-- Если руководствоваться данными определениями, то по таблице ни один заказ не был доставлен,
-- хотя это предполагается в условиях задачи (...между заказом и доставкой).
-- Так что я буду рассматривать shipment_date с order_status = 'Approved' как время доставки заказа,
-- а shipment_date с order_status = 'Сancel' как время отмены не-доставленного заказа.

-- Так как в таблице orders_new_2 отменённые заказы (order_status = 'Cancel') так же как и доставленные
-- (order_status = 'Approved') имеют своё shipment_date
-- (в данном случае для них этим временем будет являться время отмены заказа), то я рассчитал 2 случая:
-- 1) В первом: считалось самое долгое время ожидания между заказом и доставкой только для доставленных заказов
-- (order_status = 'Approved').
-- 2) Во втором: считалось самое долгое время ожидания между заказом и доставкой для всех заказов,
-- так как заказ могли долго ждать, а потом отменить, и это также стоит учесть
-- (order_status = 'Cancel' и order_status = 'Approved').
-- Разница в коде у двух случаев состоит лишь во включении или не включении условия фильтрации в подзапросе
-- (where order_status = 'Approved').


-- В подзапросе information_delivery_time:
-- С помощью join добавляю к информации о заказах, информацию о клиентах.
-- Фильтрую только заказы со статусом "Approved" (where order_status = 'Approved').
-- Нахожу время доставки заказа с точностью до секунд
-- (хотя часы, минуты и секунды в таблице у времени заказа и доставки одинаковые, так что они не влияют)
-- В подзапросе table_max_delivery_time:
-- Нахожу наибольшее время доставки среди всех заказов
--
-- В основном запросе:
-- Фильтрую по наибольшему времени заказа
-- (where delivery_time in (select max_delivery_time from table_max_delivery_time))
-- Вывожу уникальные имена клиентов

with information_delivery_time as
         (select name
               , order_id
               , (extract(epoch from max(to_timestamp(shipment_date, 'yyyy-mm-dd hh24:mi:ss')) -
                                     min(to_timestamp(order_date, 'yyyy-mm-dd hh24:mi:ss'))))::integer
                 as delivery_time
          from temporary_join.orders_new_2
                   join
               temporary_join.customers_new_2
               using (customer_id)
          where order_status = 'Approved'
          group by name, order_id),

     table_max_delivery_time as (select max(delivery_time) as max_delivery_time
                                 from information_delivery_time)

select distinct name
from information_delivery_time
where delivery_time in (select max_delivery_time from table_max_delivery_time)
limit 100;



-- 2. Найти клиентов, сделавших наибольшее количество заказов,
-- и для каждого из них найти среднее время между заказом и доставкой,
-- а также общую сумму всех их заказов.
-- Вывести клиентов в порядке убывания общей суммы заказов.


-- Так же как и в прошлой задаче, я буду рассматривать
-- shipment_date с order_status = 'Approved' как время доставки товара,
-- а shipment_date с order_status = 'Сancel' как время отмены не-доставленного заказа.
-- Под "наибольшее количество заказов" я предполагаю количество всех заказов у человека, как доставленных, так и отменённых.
-- "среднее время между заказом и доставкой" я буду рассчитывать только у доставленных заказов.
-- "общую сумму всех их заказов" я буду рассчитывать как сумму денег за отменённые и доставленные заказы.

-- Во внутреннем подзапросе max_order_count_table:
-- Вычисляю количество заказов для каждого клиента и нахожу наибольшее количество заказов среди всех клиентов.
--
-- В подзапросе customers_maximum_orders:
-- Подсчитываю количество заказов для каждого клиента (count(order_id)).
-- Рассчитываю общую сумму заказов для каждого клиента (sum(order_ammount)).
-- Фильтрую только тех клиентов, у которых количество заказов равно максимальному количеству заказов среди всех клиентов
-- (having count(order_id) = (select max(order_count)...)).
--
-- В основном запросе:
-- Соединяю по общему столбцу customer_id таблицу customers_maximum_orders с таблицами customers_new_2 и orders_new_2,
-- чтобы получить имя клиента и информацию о заказах
-- (join temporary_join.customers_new_2 using(customer_id) и join temporary_join.orders_new_2 using(customer_id)).
-- Фильтрую заказы по статусу "Approved", чтобы использовать только доставленные заказы для расчета времени доставки
-- (where order_status = 'Approved').
-- Вычисляю среднюю разницу времени между датой доставки и датой заказа в днях (extract(epoch from...)).
-- Cортирую клиентов по убыванию общей суммы заказов (order by total_order_amount desc).
-- Результирующие колонки: айди клиента, его имя, среднее время доставки в днях для клиента,
-- общее количество заказов клиента, общая сумма заказов клиента

with customers_maximum_orders as (select customer_id
                                       , count(order_id)    as order_count
                                       , sum(order_ammount) as total_order_amount
                                  from temporary_join.orders_new_2
                                  group by customer_id
                                  having count(order_id) = (select max(order_count)
                                                            from (select customer_id, count(order_id) as order_count
                                                                  from temporary_join.orders_new_2
                                                                  group by customer_id) as max_order_count_table))

select customer_id
     , name
     , avg(extract(epoch from (to_timestamp(shipment_date, 'yyyy-mm-dd hh24:mi:ss') -
                               to_timestamp(order_date, 'yyyy-mm-dd hh24:mi:ss')))::decimal /
           86400) as avg_delivery_time_in_days
     , order_count
     , total_order_amount
from customers_maximum_orders
         join temporary_join.customers_new_2 using (customer_id)
         join temporary_join.orders_new_2 using (customer_id)
where order_status = 'Approved'
group by customer_id, name, order_count, total_order_amount
order by total_order_amount desc
limit 100;



-- 3. Найти клиентов, у которых были заказы, доставленные с задержкой более чем на 5 дней,
-- и клиентов, у которых были заказы, которые были отменены.
-- Для каждого клиента вывести имя, количество доставок с задержкой, количество отмененных заказов и их общую сумму.
-- Результат отсортировать по общей сумме заказов в убывающем порядке.


-- Так же как и в прошлой задаче, я буду рассматривать
-- shipment_date с order_status = 'Approved' как время доставки товара,
-- а shipment_date с order_status = 'Сancel' как время отмены заказа.
-- Под "их общей суммой" я предполагаю сумму количества заказов в колонках
-- count_delivery_delays и count_cancel_orders.
-- Под "Результат отсортировать по общей сумме заказов в убывающем порядке"
-- я предполагаю денежную сумму за все когда-либо совершённые заказы конкретного пользователя.

-- В подзапросе merged_table_difference:
-- Преобразую строки order_date и shipment_date в формат timestamp (to_timestamp(..., 'YYYY-MM-DD HH24:MI:SS')).
-- Вычисляю разницу между датой доставки и датой заказа (to_timestamp(shipment_date) - to_timestamp(order_date)).
-- Переводит разницу во времени в дни (extract(epoch from ...) / 86400).
--
-- В основном запросе:
-- Отбираю только те строки, где есть доставка с задержкой или отмена заказа
-- (where (delivery_time_days > 5 and order_status = 'Approved') or order_status = 'Cancel').
-- Группирую данные по имени клиента (group by name).
-- Считаю количество доставленных заказов с задержкой более 5 дней
-- (count(*) filter (where delivery_time_days > 5 and order_status = 'Approved')).
-- Считаю количество отмененных заказов (count(*) filter (where order_status = 'Cancel')).
-- Складываю количество доставленных с задержкой и отмененных заказов
-- count(*) filter (where delivery_time_days > 5 and order_status = 'Approved') +
-- count(*) filter (where order_status = 'Cancel').
-- Сортирую клиентов по общей сумме всех их заказов в порядке убывания (order by sum(order_ammount) desc).
-- Ограничиваю результат 100 клиентами (limit 100).

with merged_table_difference as (select customer_id
                                      , name
                                      , order_ammount
                                      , order_status
                                      , (extract(epoch from (to_timestamp(shipment_date, 'yyyy-mm-dd hh24:mi:ss') -
                                                             to_timestamp(order_date, 'yyyy-mm-dd hh24:mi:ss'))) /
                                         86400) AS delivery_time_days
                                 from temporary_join.orders_new_2
                                          join
                                      temporary_join.customers_new_2
                                      using (customer_id))

select customer_id
     , name
     , count(*) filter (where delivery_time_days > 5 and order_status = 'Approved') as count_delivery_delays
     , count(*) filter (where order_status = 'Cancel')                              as count_cancel_orders
     , count(*) filter (where delivery_time_days > 5 and order_status = 'Approved') +
       count(*) filter (where order_status = 'Cancel')                              as number_orders_condition
     , sum(order_ammount)                                                           as total_order_amount
from merged_table_difference
group by customer_id, name
having count(*) filter (where delivery_time_days > 5 and order_status = 'Approved') +
       count(*) filter (where order_status = 'Cancel') > 0
order by sum(order_ammount) desc
limit 100;



-- Часть 2
-- Набор данных для выполнения этой задачи:
--
-- orders_2.csv
-- products_3.csv
--
-- 📌Примечание: используйте в этой задаче подзапросы
--
-- У вас есть две таблицы:
--
-- Orders содержит следующие поля:
--
-- order_id (идентификатор заказа)
-- order_date (дата заказа)
-- product_id (идентификатор продукта)
-- order_amount (сумма заказа)
--
-- Products содержит следующие поля:
--
-- product_id (идентификатор продукта)
-- product_name (наименование продукта)
-- product_category (категория продукта)
--
-- Задача: Напишите SQL-запрос, который выполнит следующие задачи:
--
-- 1. Вычислить общую сумму продаж для каждой категории продуктов.
-- 2. Определить категорию продукта с наибольшей общей суммой продаж.
-- 3. Для каждой категории продуктов, определить продукт с максимальной суммой продаж в этой категории.


-- 1. В подзапросе total_sales_product_category:
-- Объединяю таблицы с данными о заказах и продуктах.
-- Нахожу общую сумму продаж для каждой категории продуктов (sum(order_ammount)).
--
-- 2. В подзапросе product_category_highest_total_sales:
-- Определяю категорию продукта с наибольшей общей суммой продаж.
-- where sales_amount_for_each_category = (select max(sales_amount_for_each_category).
--
-- 3. В подапросе sales_amounts_for_each_product подапроса product_highest_amount_category:
-- Объединяю таблицы с данными о заказах и продуктах.
-- Суммирую продажи по каждому продукту в каждой категории (SUM(order_ammount).
-- В подапросе product_highest_amount_category:
-- Определяю продукт с максимальной суммой продаж по каждой категории продуктов.
-- (where ... in ...(select max()).
--
-- В основном запросе:
-- Объединяю все 3 подзапроса по общей колонке.
-- Сортирую по сумме продаж для каждой категории продуктов.


-- 1. Вычислить общую сумму продаж для каждой категории продуктов.

with total_sales_product_category as (select product_category,
                                             sum(order_ammount) as sales_amount_for_each_category
                                      from temporary_join.orders_2
                                               join temporary_join.products_2
                                                    using (product_id)
                                      group by product_category),


-- 2. Определить категорию продукта с наибольшей общей суммой продаж.

     product_category_highest_total_sales as (select product_category
                                              from total_sales_product_category
                                              where sales_amount_for_each_category =
                                                    (select max(sales_amount_for_each_category)
                                                     from total_sales_product_category)),


-- 3. Для каждой категории продуктов, определить продукт с максимальной суммой продаж в этой категории.

     product_highest_amount_category as (with sales_amounts_for_each_product
                                                  as (select product_category,
                                                             product_name,
                                                             sum(order_ammount) as sales_amount_for_each_product
                                                      from temporary_join.orders_2
                                                               join
                                                           temporary_join.products_2 using (product_id)
                                                      group by product_category,
                                                               product_name)

                                         select product_category,
                                                product_name,
                                                sales_amount_for_each_product
                                         from sales_amounts_for_each_product
                                         where (product_category,
                                                sales_amount_for_each_product) in
                                               (select product_category,
                                                       max(sales_amount_for_each_product)
                                                from sales_amounts_for_each_product
                                                group by product_category))

select t1.product_category as product_category,
       t2.product_category as product_category_highest_total_sales,
       t3.product_name     as product_highest_sales_amount_category,
       t1.sales_amount_for_each_category
from total_sales_product_category as t1
         left join product_category_highest_total_sales as t2
                   using (product_category)
         left join product_highest_amount_category as t3
                   using (product_category)
order by sales_amount_for_each_category desc
limit 100;


-- Пример возможного решения с использованием оконной ранжирующей функции.

select product_category,
       product_name,
       sales_amount_for_each_category,
       case
           when order_by_price_by_category = 1 then 'Категория продукта с наибольшей общей суммой продаж'
           else 'Прочее'
           end as highest_total_sales
from (select product_category,
             product_name,
             sales_amount_for_each_product,
             sales_amount_for_each_category,
             row_number()
             over (partition by product_category order by sales_amount_for_each_product desc) as order_by_price_in_category,
             rank()
             over (order by sales_amount_for_each_category desc)                              as order_by_price_by_category
      from (select product_category,
                   product_name,
                   sum(order_ammount)                                           as sales_amount_for_each_product,
                   sum(sum(order_ammount)) over (partition by product_category) as sales_amount_for_each_category
            from temporary_join.orders_2
                     join temporary_join.products_2
                          using (product_id)
            group by product_category, product_name) as t1) as t2
where order_by_price_in_category = 1
order by sales_amount_for_each_category desc
limit 100;

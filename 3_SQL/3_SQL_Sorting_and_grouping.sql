-- Часть 1
-- Набор данных для выполнения заданий:
--
-- users.csv
-- products.csv
--
-- 1. Для каждого города выведите число покупателей из соответствующей таблицы,
-- сгруппированных по возрастным категориям
-- и отсортированных по убыванию количества покупателей в каждой категории.
--
-- Примечание: под возрастной категорией подразумевается возраст человека в полных годах (например, 21, 35, 65 и т.д.).
-- Можете дополнительно написать запрос именно для “категорий”:
-- от 0 до 20 (категория young),
-- от 21 до 49 (категория adult),
-- от 50 и выше (категория old)
--
-- Пояснение: Для решения этой задачи подойдёт конструкция CASE. В качестве возраста учитывайте число полных лет.


-- В подзапросе categorized_users:
-- С помощью оператора case создаю новую колонку "age_categories",
-- где пользователи распределяются по возрастным категориям:
-- 1) Если возраст больше или равен 50 (age >= 50), пользователю присваивается категория old,
-- 2) Если возраст больше или равен 21 (age >= 21), пользователю присваивается категория adult,
-- 3) Если возраст меньше 21 (else), пользователю присваивается категория young.
--
-- В основном запросе:
-- Вычисляю количество пользователей в каждой возрастной категории для каждого города
-- с помощью функции count(age_categories).
-- Сортирую по убыванию количество покупателей в каждой категории (order by category_count desc, age_categories).
-- Устанавливаю лимит для вывода количества строк на 100 (limit 100).
-- Вывожу колонки city, age_categories, category_count.

select city
     , age_categories
     , count(age_categories) as category_count
from (select city
           , case
                 when age >= 50 then 'old'
                 when age >= 21 then 'adult'
                 else 'young'
        end as age_categories
      from temporary.users) as categorized_users
group by city, age_categories
order by category_count desc, age_categories
limit 100;


-- 2. Рассчитайте среднюю цену категорий товаров в таблице products,
-- в названиях товаров которых присутствуют слова «hair» или «home».
-- Среднюю цену округлите до двух знаков после запятой.
-- Столбец с полученным значением назовите avg_price.
--
-- Поля в результирующей таблице: avg_price, category.


-- Я буду рассчитывать среднюю цену категорий товаров по всем товарам в категории,
-- а не только по тем, в названии которых присутствуют слова «hair» или «home».
--
-- В подзапросе:
-- С помощью функции lower (lower(name)) понижаю регистр символов для корректного поиска без учета регистра.
-- Фильтрую категории (category), с помощью оператора like проверяю,
-- содержат ли названия товаров (name) слова "hair" или "home" ('%hair%' и '%home%').
-- ('%hair %' и '%home %' дают тот же результат, а '% hair %' и '% home %' - не существуют).
--
-- В основном запросе:
-- Привожу значения из колонки price к типу decimal для корректной работы с числами с плавающей запятой (price::decimal).
-- Вычисляю среднюю цену товаров для каждой категории,
-- округляя результат до двух знаков после запятой (round(avg(), 2)).
-- Устанавливаю лимит для вывода количества строк на 100 (limit 100).
-- Вывожу колонки avg_price, category.

select round(avg(price::decimal), 2) as avg_price
     , category
from temporary.products
where category in (select category
                   from temporary.products
                   where lower(name) like '%hair %'
                      or lower(name) like '%home %')
group by category
limit 100;


-- Расчёт средней цены категорий товаров по товарам категории,
-- в названии которых присутствуют слова «hair» или «home».

select round(avg(price::decimal), 2) as avg_price
     , category
from temporary.products
where lower(name) like '%hair %'
   or lower(name) like '%home %'
group by category
limit 100;



-- Часть 2
--
-- Набор данных о продавцах для выполнения следующих заданий:
--
-- sellers.csv
--
-- ⚠️ Не используйте JOIN для выполнения заданий!
--
-- 1. Назовем “успешными” (’rich’) селлерами тех:
-- кто продает более одной категории товаров и чья суммарная выручка превышает 50 000
--
-- Остальные селлеры (продают более одной категории, но чья суммарная выручка менее 50 000)
-- будут обозначаться как ‘poor’.
--
-- Выведите для каждого продавца количество категорий,
-- средний рейтинг его категорий,
-- суммарную выручку,
-- а также метку ‘poor’ или ‘rich’.
--
-- Назовите поля: seller_id, total_categ, avg_rating, total_revenue, seller_type.
-- Выведите ответ по возрастанию id селлера.
--
-- Примечание: Категория “Bedding” не должна учитываться в расчетах.


-- Под "продают более одной категории" я буду считать количество уникальных проданных категорий у продавца.
--
-- В основном запросе:
-- С помощью фильтрации (where category != 'Bedding') исключаю товары из категории "Bedding" из расчетов.
-- Вычисляю количество уникальных категорий товаров, продаваемых продавцом (count(distinct category)).
-- Вычисляю средний рейтинг всех категорий у продавца,
-- округляя результат до двух знаков после запятой (round(avg(rating::decimal), 2)).
-- Суммирую выручку от продаж для всех категорий товаров продавца (sum(revenue)).
-- С помощью конструкции CASE определяю статус продавца (rich или poor) на основе условий:
-- 1) Если суммарная выручка продавца (total_revenue) больше 50000, то seller_type устанавливается как 'rich'
-- 2) В противном случае seller_type устанавливается как 'poor'
-- Оставляю только тех продавцов, которые продают более одной категории товаров (having count(distinct category) > 1)
-- Сортирую результат по возрастанию значений в колонке seller_id (order by seller_id).
-- Ограничиваю вывод первых 100 строк (limit 100).
-- Вывожу колонки seller_id, total_category (в задании написано 'total_categ' - считаю это опечаткой),
-- avg_rating, total_revenue, seller_type.

select seller_id
     , count(distinct category)       as total_category
     , round(avg(rating::decimal), 2) as avg_rating
     , sum(revenue)                   as total_revenue
     , case
           when sum(revenue) > 50000 then 'rich'
           else 'poor'
    end                               as seller_type
from temporary.sellers
where category != 'Bedding'
group by seller_id
having count(distinct category) > 1
order by seller_id
limit 100;


-- В качестве шутки я также решил задание с добавлением "ноунеймов", которые, несомненно, в WB не нужны!)

select seller_id
     , count(distinct category)       as total_category
     , round(avg(rating::decimal), 2) as avg_rating
     , sum(revenue)                   as total_revenue
     , case
           when sum(revenue) > 50000 and count(distinct category) > 1 then 'rich'
           when sum(revenue) < 50000 and count(distinct category) > 1 then 'poor'
           else 'Ноунеймы, которые в WB не нужны!'
    end                               as seller_type
from temporary.sellers
where category != 'Bedding'
group by seller_id
order by seller_id
limit 100;



-- 2. Для каждого из неуспешных продавцов (из предыдущего задания) посчитайте,
-- сколько полных месяцев прошло с даты регистрации продавца.
--
-- Отсчитывайте от того времени, когда вы выполняете задание. Считайте, что в месяце 30 дней.
-- Например, для 61 дня полных месяцев будет 2.
--
-- Также выведите разницу между максимальным и минимальным сроком доставки среди неуспешных продавцов.
-- Это число должно быть одинаковым для всех неуспешных продавцов.
--
-- Назовите поля: seller_id, month_from_registration, max_delivery_difference.
-- Выведите ответ по возрастанию id селлера.
--
-- Примечание: Категория “Bedding” по-прежнему не должна учитываться в расчетах.


--В подзапросе registration_and_delivery:
-- С помощью фильтрации исключаю категорию "Bedding" из расчетов (where category != 'Bedding').
-- Оставляю только тех продавцов, которые продают более одной уникальной категории и имеют суммарную выручку менее 50000
-- (having count(distinct category) > 1 and sum(revenue) < 50000)
-- С помощью ((extract(epoch from) рассчитываю количество месяцев с даты первой регистрации до текущей даты
-- по условию задачи: "Считайте, что в месяце 30 дней".
-- Определяю максимальное и минимальное значение delivery_days (срока доставки) для каждого продавца
-- (max(delivery_days::int) и min(delivery_days::int)).
--
-- В подзапросе delivery_stats:
-- Определяю максимальный и минимальный срок доставки для всех неуспешных продавцов
-- (max(max_delivery_days) и min(min_delivery_days)).
--
--В основном запросе:
-- Определяю разницу между максимальным и минимальным сроком доставки для всех неуспешных продавцов
-- (over_all_max_delivery_days - over_all_min_delivery_days).
-- Сортирую результат по возрастанию seller_id (order by seller_id).
-- Ограничиваю вывод первых 100 строк (limit 100).
-- Вывожу колонки seller_id, month_from_registration, max_delivery_difference.

with registration_and_delivery as (select seller_id
                                        , max(round(extract(epoch from
                                                            age(current_date, to_date(date_reg, 'DD/MM/YYYY')))::decimal /
                                                    2592000))     as month_from_registration
                                        , max(delivery_days::int) as max_delivery_days
                                        , min(delivery_days::int) as min_delivery_days
                                   from temporary.sellers
                                   where category != 'Bedding'
                                   group by seller_id
                                   having count(distinct category) > 1
                                      and sum(revenue) < 50000),

     delivery_stats as (select max(max_delivery_days) as over_all_max_delivery_days
                             , min(min_delivery_days) as over_all_min_delivery_days
                        from registration_and_delivery)

select seller_id
     , month_from_registration
     , over_all_max_delivery_days - over_all_min_delivery_days as max_delivery_difference
from registration_and_delivery
   , delivery_stats
order by seller_id
limit 100;



-- 3. Отберите продавцов, зарегистрированных в 2022 году и продающих ровно 2 категории товаров с суммарной выручкой,
-- превышающей 75 000.
--
-- Выведите seller_id данных продавцов, а также столбец category_pair с наименованиями категорий,
-- которые продают данные селлеры.
--
-- Например, если селлер продает товары категорий “Game”, “Fitness”,
-- то для него необходимо вывести пару категорий category_pair с разделителем “-” в алфавитном порядке
-- (т.е. “Game - Fitness”).
--
-- Поля в результирующей таблице: seller_id, category_pair


-- В подзапросе seller_2022_2_75000:
-- Фильтрую продавцов, зарегистрированных в 2022 году (where date_part('year', to_date(date_reg, 'dd/mm/yyyy')) = 2022).
-- Создаю массив из уникальных категорий товаров, продаваемых продавцом, который сортирует их в алфавитном порядке
-- (array_agg(distinct category order by category) as categories).
-- Оставляю только тех продавцов, которые продают ровно две уникальные категории товаров
-- и имеют суммарную выручку более 75000 (having count(distinct category) = 2 and sum(revenue) > 75000).
--
-- В основном запросе:
-- С помощью concat объединяю с разделителем " - " первые и вторые элементы массива categories
-- (concat(categories[1], ' - ', categories[2]) as category_pair).
-- Сортирую результат по возрастанию seller_id (order by seller_id).
-- Ограничиваю вывод первых 100 строк (limit 100).
-- Вывожу колонки seller_id, category_pair.

with seller_2022_2_75000 as (select seller_id
                                  , array_agg(distinct category order by category) as categories
                             from temporary.sellers
                             where date_part('year', to_date(date_reg, 'dd/mm/yyyy')) = 2022
                             group by seller_id
                             having count(distinct category) = 2
                                and sum(revenue) > 75000)

select seller_id
     , concat(categories[1], ' - ', categories[2]) as category_pair
from seller_2022_2_75000
order by seller_id
limit 100;

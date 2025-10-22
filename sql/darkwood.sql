/* проект «секреты тёмнолесья»
 * цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * автор: антиосова елена
 * дата: 24.02.2025
*/

-- часть 1. исследовательский анализ данных
-- 1.1. доля платящих пользователей по всем данным:
with players_num as (
    select 
        count(id) as buy_players,
        (select count(id) from fantasy.users) as total_players
    from fantasy.users
    where payer = '1'
)--общее количество игроков, зарегистрированных в игре
select 
    total_players,
    buy_players,
    (cast(buy_players as numeric) / nullif(total_players, 0)::numeric(10,2)) as pay_players_share 
from players_num;
--запрос для определения доли игроков совершивших оплату
-- 1.2. доля платящих пользователей в разрезе расы персонажа:
with 
buy_player as (
    select race_id, 
    count(payer) as buy_players 
    from fantasy.users
    where payer = '1'
    group by race_id
),--количество платящих игроков
total_players as (
    select race_id, 
    count(*) as total_players 
    from fantasy.users
    group by race_id
)--общее количество зарегистрированных игроков;
select 
tp.total_players,
bp.buy_players,
r.race,
round(cast(bp.buy_players as numeric) / tp.total_players, 3) as pay_players_share
from total_players tp
join buy_player bp on tp.race_id = bp.race_id
join fantasy.race r on tp.race_id = r.race_id
order by pay_players_share desc; --доля платящих игроков от общего количества пользователей, зарегистрированных в игре в разрезе каждой расы персонажа.
-- задача 2. исследование внутриигровых покупок
-- 2.1. статистические показатели по полю amount:
select 
count(transaction_id) as count_transaction, --общее количество покупок
sum(amount) as total_amount, --суммарную стоимость всех покупок;
min(amount) as min_amount,--минимальная стоимость покупки;
max(amount) as max_amount,--максимальная стоимость покупки
avg(amount) as avg_amount, --среднее значение
stddev(amount) as std_amount,--стандартное отклонение стоимости покупки.
percentile_disc(0.5) within group(order by amount) as mediana_amount --медиана
from fantasy.events;
-- 2.2: аномальные нулевые покупки:
with transaction_num as (
    select 
    count(transaction_id) as count_null_amount,
    (select count(transaction_id) from fantasy.events) as count_transaction
    from fantasy.events
    where amount = 0 or amount is null
)--покупки с нулевой стоимостью
select 
    count_transaction,
    count_null_amount,
    (cast(count_null_amount as numeric) / nullif(count_transaction, 0):: numeric(10,2)) as pay_players_share 
from transaction_num;
select 
    i.game_items,
    count(transaction_id) as count_zero_amount
from fantasy.events as e
left join fantasy.items as i on i.item_code = e.item_code
where amount = 0 or amount is null
group by i.game_items
order by count_zero_amount desc; --топ прeметов приобретенных за 0 y.e
-- 2.3: сравнительный анализ активности платящих и неплатящих игроков:
with pay_players as (
    select 
    u.payer,
    u.id,
    count(e.transaction_id) as count_transaction, 
    sum(e.amount) as total_amount
    from fantasy.events e
    join fantasy.users u using (id)  
    where e.amount > 0  
    group by u.payer, u.id
),
total_data as (
    select 
    case 
    when payer = '1' then 'payers' 
    else 'non-payers' 
    end as player_type,
    count(id) as total_players,
    round(avg(count_transaction)::numeric, 2) as avg_transactions_per_player, 
    round(avg(total_amount)::numeric, 2) as avg_total_spent_per_player
    from pay_players
    group by payer
)
select * from total_data;
-- 2.4: популярные эпические предметы:
with total_sales as (
    select 
    i.game_items,
    count(e.transaction_id) as total_by_item,
    (select count(transaction_id) from fantasy.events e where e.amount > 0) as total_transaction 
    from fantasy.events e
    join fantasy.items i using (item_code)
    where e.amount > 0
    group by i.game_items
),
purchasing_players as (
    select
    count(distinct u.id) as players_purchased, 
    (select count(id) from fantasy.users) as total_players,  
    i.game_items
    from fantasy.events e
    join fantasy.users u on e.id = u.id
    join fantasy.items i using (item_code)
    where e.amount > 0
    group by i.game_items
)
select 
    ts.game_items,
    ts.total_transaction,
    ts.total_by_item,
    round(cast(ts.total_by_item as numeric) / nullif(ts.total_transaction, 0), 5) as items_share, 
    round(cast(pp.players_purchased as numeric) / nullif(pp.total_players, 0), 5) as players_share
from total_sales ts
join purchasing_players pp using(game_items)
order by items_share desc; 
-- часть 2. решение ad hoc-задач
with pay_players as (
select 
u.race_id,
count(distinct e.id) as pay_player
from fantasy.events e
join fantasy.users u using(id)
where payer ='1'
group by u.race_id
),
total_players_race as (
    select 
    r.race,
    p.pay_player,
    count(u.id) as total_player
    from fantasy.users u
    join fantasy.race r on u.race_id = r.race_id
    join pay_players p on u.race_id = p.race_id
    group by r.race, p.pay_player
),
total_buyer_race as (
    select 
    r.race,
    count(distinct e.id) as count_buyer,
    count(e.transaction_id) as total_purchases,
    sum(e.amount) as total_revenue  
    from fantasy.events e
    join fantasy.users u using (id)
    join fantasy.race r using(race_id)
    where e.amount > 0
    group by r.race
)
select 
    tpr.race,
    tpr.total_player, 
    tbr.count_buyer,
    tpr.pay_player,
    round(tbr.count_buyer::numeric / nullif(tpr.total_player, 0), 4) as buyer_share,
    round(tpr.pay_player::numeric / nullif(tbr.count_buyer, 0), 4) as pay_share,
    round(tbr.total_purchases::numeric / nullif(tbr.count_buyer, 0), 4) as avg_purchase_player,
    round(tbr.total_revenue::numeric / nullif(tbr.total_purchases, 0), 2) as avg_purchase_value,  
    round(tbr.total_revenue::numeric / nullif(tbr.count_buyer, 0), 2) as avg_total_spent_per_payer  
from total_players_race tpr
left join total_buyer_race tbr on tpr.race = tbr.race;
--Спасибо большое за ревью!
-- question 1

select
concat(cs.first_name,' ',cs.last_name) as name,
co.country,
max(re.return_date-re.rental_date) as period
from public.customer cs
join public.address a on cs.address_id = a.address_id 
join public.city ci on a.city_id = ci.city_id
join public.country co on ci.country_id = co.country_id 
join public.rental re on cs.customer_id = re.customer_id
join public.payment pa on cs.customer_id = pa.customer_id
group by cs.first_name, cs.last_name, co.country
order by period desc 
limit 10;

-- question 2

select 
count(rental_id),
re.customer_id
from public.rental re
where re.rental_date >= '2006-01-01 00:00:00'
and re.rental_date < '2007-01-01 00:00:00'
group by re.customer_id
having count(rental_id) >= (select 2*
(count(*)/(count(distinct re.customer_id)))
from rental re1
where re1.rental_date >= '2005-01-01 00:00:00'
and re1.rental_date < '2006-01-01 00:00:00');

-- question 3
-- (1) now() function is adjustable based on time sett-off time frame needed.

select 
cs1.customer_id,
cs1.name,
row_number() over (partition by cs1.customer_id order by cs1.gate) as period,
case
	when sum(pa1.revenue) is null then 0 
	else sum(pa1.revenue)
	end 
	as revenue
from ( 
	select 
	cs.customer_id,
	concat(cs.first_name,' ',cs.last_name) as name,
	generate_series(cs.create_date::timestamp,NOW(),'1 month') as gate --(1)
	from public.customer cs
	where cs.active = '1'
	order by cs.customer_id, gate
) cs1
left join ( select
	pa.customer_id,
	date(pa.payment_date) as month,
	sum(pa.amount) as revenue
	from public.payment pa
	group by pa.customer_id, month
	order by pa.customer_id, month
	) pa1 on cs1.customer_id = pa1.customer_id
	and extract(year from cs1.gate) = extract(year from pa1.month)
	and extract(month from cs1.gate) = extract(month from pa1.month)
group by cs1.customer_id, cs1.gate, cs1.name
order by customer_id, period;

-- question 4

select 
pa.customer_id,
cs.first_name,
cs.last_name,
pa.payment_date,
sum(pa.amount),
row_number() over (partition by pa.customer_id order by pa.payment_date) as payment
from public.payment pa
join customer cs on pa.customer_id = cs.customer_id
group by pa.customer_id,cs.first_name, cs.last_name, pa.payment_date, pa.amount
order by pa.customer_id asc
limit 50;

-- question 5

select 
pa.customer_id,
cs.first_name,
cs.last_name,
date (pa.payment_date),
sum(pa.amount) as total
from public.payment pa
join public.customer cs on pa.customer_id = cs.customer_id
group by pa.customer_id,cs.first_name, cs.last_name, date(pa.payment_date)
order by pa.customer_id asc;

-- question 6

-- assumption : 1.customer.create_date is the registered date
--				2. LTV/CLC forumula = (1 year revenue from joining date per customer)/(total revenue from all customers in year) where 1 year interval is per customer since joining 
-- disclaimer : I use interval 1 year function as the question want EXACTLY 1 year from 00.00.000 to next year 00.00.00 but after gone through the result we find no customer make any payment on exactly 1 year, that is why I also come up with an assumption that the calculation of the year might be 366 days instead of 365 days.
--			  : so, I Provide two solutions 1st solustion with 1 year interval,
--              2nd solution with 1 year 1 day days 

-- 1st Solution = 1 year interval 

select 
cs1. customer_id,
cs1. name,
cs1. RevenueCustomer,
cs2.RevenueTotal,
round(cast(((cs1.RevenueCustomer/cs2.RevenueTotal)*100) as numeric),2) as percentage
from 
	(select 
	cs.customer_id,
	concat(cs.first_name,' ',cs.last_name) as name,
	concat(date(cs.create_date),' - ',date(cs.create_date+ interval '1 year')) as interval,
	sum(pa.amount) as RevenueCustomer
	from 
	public.customer cs
	join public.payment pa on cs.customer_id = pa.customer_id
	where pa.payment_date >= cs.create_date
	and pa.payment_date < (cs.create_date + interval '1 year')
	group by cs.customer_id
	order by cs.customer_id) cs1
join
	(select 
	concat(date(cs.create_date),' - ',date(cs.create_date + interval '1 year')) as interval,
	sum(pa.amount) as RevenueTotal
	from public.customer cs
	join public.payment pa on cs.customer_id = pa.customer_id
	where pa.payment_date >= cs.create_date
	and pa.payment_date < (cs.create_date + interval '1 year')
	group by interval) cs2 on cs1.interval = cs2.interval;

-- 2nd Solution = 1 year interval 1 day

select 
cs1. customer_id,
cs1. name,
cs1. RevenueCustomer,
cs2.RevenueTotal,
round(cast(((cs1.RevenueCustomer/cs2.RevenueTotal)*100) as numeric),2) as percentage
from 
	(select 
	cs.customer_id,
	concat(cs.first_name,' ',cs.last_name) as name,
	concat(date(cs.create_date),' - ',date(cs.create_date+ interval '1 year 1 day')) as interval,
	sum(pa.amount) as RevenueCustomer
	from 
	public.customer cs
	join public.payment pa on cs.customer_id = pa.customer_id
	where pa.payment_date >= cs.create_date
	and pa.payment_date < (cs.create_date + interval '1 year 1 day')
	group by cs.customer_id
	order by cs.customer_id) cs1
join
	(select 
	concat(date(cs.create_date),' - ',date(cs.create_date + interval '1 year 1 day')) as interval,
	sum(pa.amount) as RevenueTotal
	from public.customer cs
	join public.payment pa on cs.customer_id = pa.customer_id
	where pa.payment_date >= cs.create_date
	and pa.payment_date < (cs.create_date + interval '1 year 1 day')
	group by interval) cs2 on cs1.interval = cs2.interval;
	



-- Question 7

-- Here are some insights for the store from internal(store) perspective and external(customer) perspective.

-- 1st : This list represent the most profitable movie base on category/genres to the least.
-- The sport category is the most profitable category and contributing more profit in sales for the store. The store staff/team need to make sure they always have a stock for sport category.
-- from the tops category we can maps customers category interest, so we can increase the varience/stock of the category. 

select ca.name as genre,
count(cs.customer_id) as total_demand,
sum(pa.amount) as total_sales
from public.category ca
join public.film_category fc on ca.category_id = fc.category_id
join public.film fi on fc.film_id = fi.film_id 
join public.inventory inv on fi.film_id = inv.film_id
join public.rental re on inv.inventory_id = re.inventory_id
join public.customer cs on re.customer_id = cs.customer_id
join public.payment pa on re.rental_id = pa.rental_id
group by genre
order by total_demand desc
limit 10;

-- 2nd : This list represent the most profitable country for the business.
-- India has the largest customer base, resulting to an increase in sales and more profit.

select co.country,
count(*) as total_customers,
sum(pa.amount) as total_sales
from public.country co
join public.city ci on co.country_id = ci.country_id
join public.address ad on ci.city_id = ad.city_id
join public.customer cs on ad.address_id = cs.address_id
join public.payment pa on cs.customer_id = pa.customer_id
group by co.country 
order by total_sales desc
limit 10;

-- 3rd : This list represent the average rental rate
-- for the most tops genre in the store, the store can increase the rental rate based on the customer demands

select ca.name as movie_genre,
round(cast((avg(fi.rental_rate)) as numeric),2) as average_rental_rate
from public.category ca
join public.film_category fc on ca.category_id = fc.category_id
join public.film fi on fc.film_id = fi.film_id
group by movie_genre
order by average_rental_rate desc
limit 10;

-- 4th : This list represent the tops most popular artists
-- from the list we can use it as a reference for the most popular artists so the store can use the artist as the store influencer to got more attention from customers.

select concat(ac.first_name,' ', ac.last_name) as artist_name,
count(fa.actor_id) as total_movie
from public.film fi
join public.film_actor fa on fi.film_id = fa.film_id 
join public.actor ac on fa.actor_id = ac.actor_id
group by artist_name 
order by total_movie desc
limit 10;

-- 5th : This list represent the customer with most transactions
-- Based on this list, we can give a rewards for customers with the most transactions,  as a part of the promotion strategy to increase customer enggagement 
select 
concat(cs.first_name,' ',cs.last_name) as name,
cs.email,
count(*) as total_transactions
from public.customer cs
join public.payment pa on cs.customer_id = pa.customer_id
group by 1,2
order by 3 desc
limit 10;

-- 6th : This list represent the customer with the most profits to the store
-- Based on this list, we can give a rewards for customers with the most profit,  as a part of the promotion strategy to increase customer enggagement
select 
concat(cs.first_name,' ',cs.last_name) as name,
cs.email,
sum(pa.amount) as total_amount_paid
from public.customer cs
join public.payment pa on cs.customer_id = pa.customer_id
group by 1,2
order by 3 desc
limit 10;





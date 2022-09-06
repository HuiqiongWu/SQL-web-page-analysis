show databases;
USE mavenfuzzyfactory;
-- Traffic Sources Analysis
-- 1. Finding top traffic sources
/* 
where are the bulk of the website sessions comming from, throuh 04/12/2022? 
Would like to see a breakdown by UTM source, campaign and referring domain.
*/
SELECT * FROM website_sessions;

SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions
    FROM website_sessions
    WHERE created_at < '2012-04-12'
    GROUP BY
		utm_source,
        utm_campaign,
		http_referer
	ORDER BY
		sessions DESC;
 
-- 2. Traffic source conversion
/* 
what is the coversion rate (CVR) from session to order? require CVR at least 4%
*/
SELECT
	COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) * 100 AS cvr
    FROM website_sessions 
		LEFT JOIN orders
			ON orders.website_session_id = website_sessions.website_session_id
	WHERE 
		website_sessions.created_at < '2012-04-12' AND
        utm_source = 'gsearch' AND
        utm_campaign = 'nonbrand';

-- 3. Bid optimization & Trend Analysis --> optimize marketing budget
SELECT 
	primary_product_id,
    COUNT(DISTINCT CASE WHEN items_purchased = 1 THEN order_id ELSE NULL END) AS count_single_item_orders,
    COUNT(DISTINCT CASE WHEN items_purchased = 2 THEN order_id ELSE NULL END) AS count_two_items_orders
    FROM orders
    GROUP BY 
		primary_product_id;
-- 4. Traffic source trending
/*
Request date is 2012-05-12.
Traffic source trending: based on conversion rate analysis, bid down gsearch nonbrand on 2012-04-12.
pull gsearch nonbrand trended session volumn, by week to see if the bid changes have caused volumn to drop at all?
*/		
SELECT 
	MIN(DATE(created_at)) AS week_start_date,
    COUNT(DISTINCT website_session_id) AS sessions
    FROM website_sessions
    WHERE 
		created_at < "2012-05-12" AND
        utm_source = 'gsearch' AND 
        utm_campaign = 'nonbrand'
    GROUP BY 
		YEAR(created_at),
		WEEK(created_at);
        
-- 5. Bid optimization for paid traffic 
 /*
the site on mobile device the other day, and the experience was not great.
pull conversion rates from session to order, by device type?
If desktop performance is better than on mobile we may be able to bid up for desktop specifically to get more volume?
*/
SELECT 
	device_type,
	COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.website_session_id) AS orders,
    COUNT(DISTINCT orders.website_session_id)/COUNT(DISTINCT website_sessions.website_session_id)*100 AS cvr
    FROM website_sessions
		LEFT JOIN orders
			ON website_sessions.website_session_id = orders.website_session_id
	WHERE 
		website_sessions.created_at < "2012-05-11" AND
        utm_source = 'gsearch' AND 
        utm_campaign = 'nonbrand'
	GROUP BY 
		device_type;
        
-- 6. Trending granular segments        
/*
After your device-level analysis of conversion rates, we realized desktop was doing well, so we bid our gsearch nonbrand desktop campaigns up on 2012-05-19.
Could you pull weekly trends for both desktop and mobile so we can see the impact on volume?
You can use 2012-04-15 until the bid change as a baseline.
*/
SELECT 
    MIN(DATE(created_at)) AS week_start_date,
	COUNT(DISTINCT CASE WHEN device_type = "desktop" THEN website_session_id ELSE NULL END) AS dtop_sessions,
    COUNT(DISTINCT CASE WHEN device_type = "mobile" THEN website_session_id ELSE NULL END) AS mob_sessions
    FROM website_sessions
	WHERE
		created_at < '2012-06-09' 
        AND created_at > '2012-04-15'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
	GROUP BY 
        YEAR(created_at),
        WEEK(created_at);
	
-- Website Performance analysis
-- 1. finding tip website pages
/*
the most-viewed website pages, ranked by session volume
*/
SELECT * FROM website_pageviews;
SELECT 
	pageview_url,
    COUNT(DISTINCT website_session_id) AS pvs
    FROM website_pageviews
    GROUP BY pageview_url
    ORDER BY pvs DESC;

-- 2. finding top website pages
/*
pull a list of the top entry pages
pull all entry pages and rank them on entry volume
*/
CREATE TEMPORARY TABLE first_pv_per_session
SELECT
    website_session_id,
    MIN(website_pageview_id) AS first_pv
    FROM website_pageviews
    GROUP BY 
        website_session_id;

SELECT 
	website_pageviews.pageview_url AS landing_page_url,
    COUNT(DISTINCT first_pv_per_session.website_session_id) AS sessions_hitting_page
	FROM first_pv_per_session
		LEFT JOIN website_pageviews
			ON first_pv_per_session.first_pv = website_pageviews.website_pageview_id
    GROUP BY
		website_pageviews.pageview_url;

-- 3. bounce rates calculation
/*
The other day you showed us that all of our traffic is landing on the homepage right now. We should check how that landing page is performing.
Can you pull bounce rates for traffic landing on the homepage? I would like to see three numbers...Sessions, Bounced Sessions, and % of Sessions which Bounced (aka “Bounce Rate”).
1. finding the first website_pageview_id for relevant sessions
2. identifying the landing age of each session
3. counting pageviews for each session to identify "bounce"
4. summarizing by counting total sessions and bounced sessions
*/
SELECT * FROM first_pv_per_session;

CREATE TEMPORARY TABLE sessions_w_home_landing_page
SELECT
	first_pageview.website_session_id,
    website_pageviews.pageview_url AS landing_page
	FROM first_pv_per_session
		LEFT JOIN website_pageviews
			ON website_pageviews.website_session_id = first_pv_per_session.website_session_id
        WHERE landing_page = '/home';
        
CREATE TEMPORARY TABLE bounced_sessions
SELECT
	sessions_w_home_landing_page.website_session_id,
    sessions_w_home_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pages_viewed
    
    FROM sessions_w_home_landing_page
		LEFT JOIN website_pageviews
			ON website_pageviews.website_session_id = sessions_w_home_landing_page.website_session_id
	
    GROUP BY 
		sessions_w_home_landing_page.website_session_id,
        sessions_w_home_landing_page.landing_page
        
	HAVING 
		COUNT(website_pageviews.website_pageview_id) = 1;
        
SELECT
	sessions_w_home_landing_page.website_session_id,
    bounced_sessions.website_session_id AS bounced_website_session_id
    FROM sessions_w_home_landing_page
		LEFT JOIN bounced_sessions
			ON sessions_w_home_landing_page.website_session_id = bounced_sessions.website_session_id
	ORDER BY
		sessions_w_home_landing_page.website_session_id;
        
SELECT 
	COUNT(DISTINCT sessions_w_home_landing_page.website_session_id) AS total_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id)/COUNT(DISTINCT sessions_w_home_landing_page.website_session_id) AS bounce_rate
    FROM sessions_w_home_landing_page
		LEFT JOIN bounced_sessions
			ON sessions_w_home_landing_page.website_session_id = bounced_sessions.website_session_id;
    
-- 4. landing page analysis
/*
Based on your bounce rate analysis, we ran a new custom landing page (/lander-1) in a 50/50 test against the homepage (/home) for our gsearch nonbrand traffic.
Can you pull bounce rates for the two groups so we can evaluate the new page? Make sure to just look at the time period where /lander-1 was getting traffic, so that it is a fair comparison.
*/
SELECT * FROM website_pageviews WHERE pageview_url = '/lander-1'; -- to get the tme that /lander-1 was getting traffic

CREATE TEMPORARY TABLE first_test_pageviews
SELECT 
	website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
    FROM website_pageviews
		INNER JOIN website_sessions
			ON website_sessions.website_session_id = website_pageviews.website_session_id
            AND website_sessions.created_at < '2012-07-08'
            AND website_pageviews.website_pageview_id > 23504
            AND utm_source = 'gsearch'
            AND utm_campaign = 'nonbrand'
	GROUP BY 
		website_pageviews.website_session_id;
	        
SELECT * FROM first_test_pageviews;

CREATE TEMPORARY TABLE non_brand_test_sessions_w_landing_page
SELECT
	first_test_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
    FROM first_test_pageviews
		LEFT JOIN website_pageviews
			ON website_pageviews.website_pageview_id = first_test_pageviews.min_pageview_id
	WHERE website_pageviews.pageview_url IN ('/home', '/lander-1');

SELECT * FROM non_brand_test_sessions_w_landing_page;

CREATE TEMPORARY TABLE nonbrand_test_bounced_sessions
SELECT 
	non_brand_test_sessions_w_landing_page.website_session_id,
    COUNT(website_pageviews.website_pageview_id) AS count_of_page,
    non_brand_test_sessions_w_landing_page.landing_page
    FROM non_brand_test_sessions_w_landing_page
		LEFT JOIN website_pageviews
			ON non_brand_test_sessions_w_landing_page.website_session_id = website_pageviews.website_session_id
	GROUP BY
		non_brand_test_sessions_w_landing_page.website_session_id,
        non_brand_test_sessions_w_landing_page.landing_page
	HAVING 
		COUNT(website_pageviews.website_pageview_id) = 1;
        
SELECT * FROM nonbrand_test_bounced_sessions;

SELECT
	non_brand_test_sessions_w_landing_page.landing_page,
	COUNT(DISTINCT non_brand_test_sessions_w_landing_page.website_session_id) AS total_sessions,
    COUNT(DISTINCT nonbrand_test_bounced_sessions.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT nonbrand_test_bounced_sessions.website_session_id) / COUNT(DISTINCT non_brand_test_sessions_w_landing_page.website_session_id) AS bounced_rate
    FROM non_brand_test_sessions_w_landing_page
		LEFT JOIN nonbrand_test_bounced_sessions
			ON non_brand_test_sessions_w_landing_page.website_session_id = nonbrand_test_bounced_sessions.website_session_id
	GROUP BY 
		non_brand_test_sessions_w_landing_page.landing_page;

-- landing page trend analysis
/*
Could you pull the volume of paid search nonbrand traffic landing on /home and /lander-1, trended weekly since June 1st? I want to confirm the traffic is all routed correctly.
Could you also pull our overall paid search bounce rate trended weekly? I want to make sure the lander change has improved the overall picture.
*/
SELECT * FROM website_sessions;
DROP TABLE landing_page_sessions;
CREATE TEMPORARY TABLE landing_page_sessions
SELECT 
	WEEK(website_pageviews.created_at) AS week_created,
	website_pageviews.website_session_id,
    MIN(website_pageview_id) AS fv_page_id,
    pageview_url AS landing_page
    FROM website_pageviews
		LEFT JOIN website_sessions
			ON website_pageviews.website_session_id = website_sessions.website_session_id
	WHERE 
		utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
        AND website_sessions.created_at > '2012-06-01'
        AND pageview_url IN ('/home', '/lander-1')
	GROUP BY
		website_pageviews.website_session_id,
        pageview_url,
        WEEK(website_pageviews.created_at);

SELECT * FROM landing_page_sessions;

DROP TABLE landing_page_bounced_sessions;         
CREATE TEMPORARY TABLE landing_page_bounced_sessions
SELECT 
	week_created,
	landing_page_sessions.website_session_id,
    COUNT(website_pageviews.website_pageview_id) AS count_of_page,
    landing_page_sessions.landing_page
    FROM landing_page_sessions
		LEFT JOIN website_pageviews
			ON landing_page_sessions.website_session_id = website_pageviews.website_session_id
	GROUP BY
		landing_page_sessions.website_session_id,
        landing_page_sessions.landing_page,
        week_created
	HAVING 
		COUNT(website_pageviews.website_pageview_id) = 1;

SELECT * FROM landing_page_bounced_sessions;

SELECT 
	week_created,
    COUNT(DISTINCT CASE WHEN landing_page = '/home' THEN landing_page_sessions.website_session_id ELSE NULL END) AS homapage_total_sessions,
    COUNT(DISTINCT CASE WHEN landing_page = '/lander-1' THEN landing_page_sessions.website_session_id ELSE NULL END) AS lander1_total_sessions
    FROM landing_page_sessions
	GROUP BY
        week_created;
		
SELECT
	landing_page_sessions.week_created,
    COUNT(DISTINCT CASE WHEN landing_page_bounced_sessions.landing_page = '/home' THEN landing_page_bounced_sessions.website_session_id ELSE NULL END)/ COUNT(DISTINCT CASE WHEN landing_page_sessions.landing_page = '/home' THEN landing_page_sessions.website_session_id ELSE NULL END) AS homepage_bounced_rate,
    COUNT(DISTINCT CASE WHEN landing_page_bounced_sessions.landing_page = '/lander-1' THEN landing_page_bounced_sessions.website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN landing_page_sessions.landing_page = '/lander-1' THEN landing_page_sessions.website_session_id ELSE NULL END) AS lander1_bounced_rate
    FROM landing_page_sessions
		LEFT JOIN landing_page_bounced_sessions
			ON landing_page_sessions.website_session_id = landing_page_bounced_sessions.website_session_id
	GROUP BY 
		landing_page_sessions.week_created;

        
	



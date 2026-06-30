defmodule PlausibleWeb.Api.StatsController.ScreenSizesTest do
  use PlausibleWeb.ConnCase

  defp query_screen_sizes(conn, site, opts) do
    params = %{
      "dimensions" => Keyword.get(opts, :dimensions, ["visit:device"]),
      "date_range" => Keyword.get(opts, :date_range, "all"),
      "filters" => Keyword.get(opts, :filters, []),
      "metrics" => Keyword.get(opts, :metrics, ["visitors", "percentage"]),
      "include" => Keyword.get(opts, :include, nil),
      "pagination" => Keyword.get(opts, :pagination, nil),
      "order_by" => Keyword.get(opts, :order_by, nil)
    }

    conn
    |> post("/api/stats/#{site.domain}/query", params)
    |> json_response(200)
  end

  describe "GET /api/stats/:domain/screen-sizes" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "returns screen sizes by new visitors", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Laptop")
      ])

      response = query_screen_sizes(conn, site, date_range: "day")

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Laptop"], "metrics" => [1, 33.33]}
             ]
    end

    test "returns bounce_rate and visit_duration when detailed=true", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 12:00:00],
          screen_size: "Desktop"
        ),
        build(:pageview,
          user_id: 123,
          timestamp: ~N[2021-01-01 12:10:00],
          screen_size: "Desktop"
        ),
        build(:pageview, timestamp: ~N[2021-01-01 12:00:00], screen_size: "Desktop"),
        build(:pageview, timestamp: ~N[2021-01-01 12:00:00], screen_size: "Laptop")
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          metrics: ["visitors", "bounce_rate", "visit_duration", "percentage"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 50, 300, 66.67]},
               %{"dimensions" => ["Laptop"], "metrics" => [1, 100, 0, 33.33]}
             ]
    end

    test "returns screen sizes for user making multiple sessions", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          screen_size: "Laptop",
          timestamp: ~N[2021-01-01 05:00:00]
        )
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          order_by: [["visit:device", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [1, 100.0]},
               %{"dimensions" => ["Laptop"], "metrics" => [1, 100.0]}
             ]
    end

    test "returns (not set) when appropriate", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          screen_size: ""
        ),
        build(:pageview,
          screen_size: "Desktop"
        )
      ])

      response1 =
        query_screen_sizes(conn, site,
          date_range: "day",
          order_by: [["visit:device", "asc"]]
        )

      assert response1["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["Desktop"], "metrics" => [1, 50.0]}
             ]

      response2 =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is", "visit:device", ["(not set)"]]]
        )

      assert response2["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [1, 100.0]}
             ]
    end

    test "select empty imported_devices as (not set), merging with the native (not set)", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview, user_id: 123),
        build(:imported_devices, visitors: 1),
        build(:imported_visitors, visitors: 1)
      ])

      response =
        query_screen_sizes(conn, site, date_range: "day", include: %{"imports" => true})

      assert response["results"] == [
               %{"dimensions" => ["(not set)"], "metrics" => [2, 100.0]}
             ]
    end

    test "returns screen sizes with :is filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop"
        ),
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          screen_size: "Tablet"
        )
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is", "event:props:author", ["John Doe"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [1, 100.0]}
             ]
    end

    test "returns screen sizes with :is_not filter on custom pageview props", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          user_id: 123,
          screen_size: "Desktop",
          "meta.key": ["author"],
          "meta.value": ["John Doe"]
        ),
        build(:pageview,
          screen_size: "Mobile",
          "meta.key": ["author"],
          "meta.value": ["other"]
        ),
        build(:pageview,
          screen_size: "Tablet"
        )
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is_not", "event:props:author", ["John Doe"]]],
          order_by: [["visit:device", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Mobile"], "metrics" => [1, 50.0]},
               %{"dimensions" => ["Tablet"], "metrics" => [1, 50.0]}
             ]
    end

    test "returns screen sizes by new visitors with imported data", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Desktop"),
        build(:pageview, screen_size: "Laptop")
      ])

      populate_stats(site, [
        build(:imported_devices, device: "Mobile"),
        build(:imported_devices, device: "Laptop"),
        build(:imported_visitors, visitors: 2)
      ])

      response1 = query_screen_sizes(conn, site, date_range: "day")

      assert response1["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Laptop"], "metrics" => [1, 33.33]}
             ]

      response2 =
        query_screen_sizes(conn, site, date_range: "day", include: %{"imports" => true})

      assert response2["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 40.0]},
               %{"dimensions" => ["Laptop"], "metrics" => [2, 40.0]},
               %{"dimensions" => ["Mobile"], "metrics" => [1, 20.0]}
             ]
    end

    test "returns screen sizes when filtering by imported screen size", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, screen_size: "Desktop"),
        build(:imported_devices, device: "Desktop"),
        build(:imported_devices, device: "Laptop"),
        build(:imported_visitors, visitors: 2)
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is", "visit:device", ["Desktop"]]],
          include: %{"imports" => true}
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 100.0]}
             ]
    end

    test "returns screen sizes for user making multiple sessions by no of visitors with imported data",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview,
          user_id: 1,
          screen_size: "Desktop",
          timestamp: ~N[2021-01-01 00:00:00]
        ),
        build(:pageview,
          user_id: 1,
          screen_size: "Laptop",
          timestamp: ~N[2021-01-01 05:00:00]
        )
      ])

      populate_stats(site, [
        build(:imported_devices, device: "Desktop", date: ~D[2021-01-01]),
        build(:imported_devices, device: "Laptop", date: ~D[2021-01-01]),
        build(:imported_visitors, visitors: 1, date: ~D[2021-01-01])
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: ["2021-01-01", "2021-01-01"],
          include: %{"imports" => true},
          order_by: [["visit:device", "asc"]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 100.0]},
               %{"dimensions" => ["Laptop"], "metrics" => [2, 100.0]}
             ]
    end

    test "calculates conversion_rate when filtering for goal", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Signup")

      populate_stats(site, [
        build(:pageview, user_id: 1, screen_size: "Desktop"),
        build(:pageview, user_id: 2, screen_size: "Desktop"),
        build(:event, user_id: 1, name: "Signup")
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Signup"]]],
          metrics: ["visitors", "total_visitors", "group_conversion_rate"]
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [1, 2, 50.0]}
             ]
    end

    test "returns screen sizes with not_member filter type", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, referrer_source: "Google", screen_size: "Desktop"),
        build(:pageview, referrer_source: "Bad source", screen_size: "Desktop"),
        build(:pageview, referrer_source: "Google", screen_size: "Desktop"),
        build(:pageview, referrer_source: "Twitter", screen_size: "Mobile"),
        build(:pageview,
          referrer_source: "Second bad source",
          screen_size: "Mobile"
        )
      ])

      response =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is_not", "visit:source", ["Bad source", "Second bad source"]]]
        )

      assert response["results"] == [
               %{"dimensions" => ["Desktop"], "metrics" => [2, 66.67]},
               %{"dimensions" => ["Mobile"], "metrics" => [1, 33.33]}
             ]
    end

    @tag :ee_only
    test "return revenue metrics for screen sizes breakdown", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, screen_size: "Mobile"),
        build(:event,
          name: "Payment",
          user_id: 1,
          revenue_reporting_amount: Decimal.new("1000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 2, screen_size: "Mobile"),
        build(:event,
          name: "Payment",
          user_id: 2,
          revenue_reporting_amount: Decimal.new("2000"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 3, screen_size: "Mobile"),
        build(:pageview, user_id: 4, screen_size: "Desktop"),
        build(:event,
          name: "Payment",
          user_id: 4,
          revenue_reporting_amount: Decimal.new("500"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 5, screen_size: "Desktop"),
        build(:pageview, user_id: 6),
        build(:event,
          name: "Payment",
          user_id: 6,
          revenue_reporting_amount: Decimal.new("600"),
          revenue_reporting_currency: "USD"
        ),
        build(:pageview, user_id: 7),
        build(:event,
          name: "Payment",
          user_id: 7,
          revenue_reporting_amount: nil
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :USD})

      response =
        query_screen_sizes(conn, site,
          date_range: "day",
          filters: [["is", "event:goal", ["Payment"]]],
          metrics: [
            "visitors",
            "total_visitors",
            "group_conversion_rate",
            "average_revenue",
            "total_revenue"
          ],
          order_by: [["visitors", "desc"], ["visit:device", "asc"]]
        )

      assert response["results"] == [
               %{
                 "dimensions" => ["(not set)"],
                 "metrics" => [
                   2,
                   2,
                   100.0,
                   %{
                     "currency" => "USD",
                     "long" => "$600.00",
                     "short" => "$600.0",
                     "value" => 600.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$600.00",
                     "short" => "$600.0",
                     "value" => 600.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["Mobile"],
                 "metrics" => [
                   2,
                   3,
                   66.67,
                   %{
                     "currency" => "USD",
                     "long" => "$1,500.00",
                     "short" => "$1.5K",
                     "value" => 1500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$3,000.00",
                     "short" => "$3.0K",
                     "value" => 3000.0
                   }
                 ]
               },
               %{
                 "dimensions" => ["Desktop"],
                 "metrics" => [
                   1,
                   2,
                   50.0,
                   %{
                     "currency" => "USD",
                     "long" => "$500.00",
                     "short" => "$500.0",
                     "value" => 500.0
                   },
                   %{
                     "currency" => "USD",
                     "long" => "$500.00",
                     "short" => "$500.0",
                     "value" => 500.0
                   }
                 ]
               }
             ]
    end
  end
end

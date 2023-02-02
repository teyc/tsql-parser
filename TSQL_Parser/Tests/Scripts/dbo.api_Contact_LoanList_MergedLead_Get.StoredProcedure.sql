SELECT DISTINCT ISNULL((
                           CASE 1
                               WHEN 2
                                   THEN 2
                               ELSE 3
                               END
                           ), '') AS F
FROM FAMILY_LOAN AS FL
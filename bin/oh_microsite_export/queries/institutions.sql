select
    node.title
from
    node
WHERE
    node.type  = 'institution'
ORDER BY
    node.title
#!/command/with-contenv bash
source /assets/functions/00-container
if var_true "${DRUPAL_FILES_PERM_FIXED}"; then
    echo "starting fixed perms perm fixed"
    #chown nginx:www-data -R /var/www/html/*/sites/*/files
    #chmod -R 777 /var/www/html/*/sites/*/files

    #chown nginx:www-data -R /var/www/html/sites/*/files
    #chmod -R 777 /var/www/html/sites/*/files

    cd /var/www/html/*/sites/default/files
    find . -not -path "*.snapshot" -mindepth 1 -maxdepth 1 -exec chown -R nginx:www-data {} +
    find . -not -path "*.snapshot" -mindepth 1 -maxdepth 1 -exec chmod -R 777 {} +

    ## For Drupal 7
    if [ -d "/var/www/html/sites/default/files" ]; then
        cd /var/www/html/sites/default/files
        find . -not -path "*.snapshot" -mindepth 1 -maxdepth 1 -exec chown -R nginx:www-data {} +
        find . -not -path "*.snapshot" -mindepth 1 -maxdepth 1 -exec chmod -R 777 {} +
    fi

    echo "end fixed drupal files perm"
fi

liftoff

#!/command/with-contenv bash
source /assets/functions/00-container
if var_true "${DRUPAL_FILES_PERM_FIXED}"; then
    echo "starting fixed perms perm fixed"
    chown nginx:www-data -R /var/www/html/*/sites/*/files
    chmod -R 777 /var/www/html/*/sites/*/files

    chown nginx:www-data -R /var/www/html/sites/*/files
    chmod -R 777 /var/www/html/sites/*/files

    echo "end fixed drupal files perm"
fi

liftoff

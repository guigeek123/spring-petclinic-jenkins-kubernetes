import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret
//Init
credentials_store = Jenkins.instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
global_domain = Domain.global()
// Find if already loaded and delete
for (c in credentials_store.getCredentials(global_domain)) {
    if (c.class == StringCredentialsImpl ) {
        if(c.getId().equals("%ID")) {
            credentials_store.removeCredentials(global_domain, c);
            break;
        }
    }
}
// Add new secret
secret = new Secret("%SECRET" )
newcred = new StringCredentialsImpl(CredentialsScope.GLOBAL, "%ID", "", secret )
credentials_store.addCredentials(global_domain, newcred)

public with sharing class Redirects {
    // Assists users with displaying Skuid only if licensed to do so.
    // Otherwise, standard pages are displayed
    public boolean canUseSkuid {
        public get {
            if (canUseSkuid == null) canUseSkuid = UserInfo.isCurrentUserLicensed('skuid');
            return canUseSkuid;
        } 
        // We include a setter so that we can manually override this property during unit tests
        public set;
    }
    private transient ApexPages.StandardController stdCtl;
    private transient ApexPages.StandardSetController setCtl;
    
    private PageReference getStandardPageReference() {
        // Create a reference to a standard Salesforce Page action
        PageReference result;
        Map<String,String> params = ApexPages.currentPage().getParameters(); 
        if (this.stdCtl != null) {
            // See if we have an id param
            String idParam = params.get('id');
            // Get the standard controller prototype record
            SObject proto = this.stdCtl.getRecord();
            // If proto.Id is not null, and idParam IS null,
            // then assign the proto Id to idParam
            if (idParam == null && proto.Id != null) idParam = proto.Id;
            // Get the Key Prefix of our object
            String keyPrefix = proto.getSObjectType().getDescribe().getKeyPrefix();
            if (idParam != null || proto.Id != null) {
                if (params.get('clone') == '1') {
                    // We're on a clone page
                    result = new PageReference('/'+keyPrefix+'/e');
                    result.getParameters().put('id',idParam);
                    result.getParameters().put('clone','1');
                } 
                // FOr edit mode, the only way we can consistenly get a user to the edit page
                // is for them to start on the View/Detail page
                // and then click the Edit button,
                // in which case the retURL param will start with with '/'+idParam
                else if (params.get('retURL') != null 
                && EncodingUtil.urlDecode(params.get('retURL'),'UTF-8').startsWith('/'+idParam.substring(0,15))) {
                    // We're (hopefully) trying to reach an edit page for a record
                    result = new PageReference('/'+idParam+'/e');
                } else if (params.containsKey('delID')) {
                    // We want to DELETE the record
                    result = stdCtl.delete();
                } else {
                    // We want to VIEW the record
                    result = new PageReference('/'+idParam);
                }
            } else {
                // We're on a new page
                result = new PageReference('/'+keyPrefix+'/e');
                result.getParameters().remove('id');
                // Pass along the selected record type and entity parameters,
                // if they exist --- these will be populated if we used the
                // standard Record Type selection step
                if (params.get('RecordType') != null) {
                    result.getParameters().put('RecordType',params.get('RecordType'));
                    result.getParameters().put('ent',params.get('ent'));
                }   
            }
        } else if (this.setCtl != null) {
            // Get the keyprefix of the object we're dealing with,
            // and use it to instantiate our target page reference
            SObject proto = this.setCtl.getRecord();
            String keyPrefix = proto.getSObjectType().getDescribe().getKeyPrefix();
            String filterId = params.get('fcf');
            result = new PageReference('/'+keyPrefix+((filterId == null)?'/o':''));
            // See if we have a filter id,
            // and if we do pass it in to the page
            if (filterId != null) {
                result.getParameters().put('fcf',filterId.substring(0,15));
            }
        }
        return result;  
    }
    
    //
    // <begin> NO SKUID ONLY
    //
    
    public PageReference getRedirect() {
        return redirect();
    }
    
    // If the user is NOT Skuid licensed,
    // return a reference to a Standard Salesforce page.
    // Otherwise, return a reference to the UI page
    public PageReference redirect() {
        PageReference result = getStandardPageReference();
        if (!canUseSkuid && result != null) {
            // Make sure we go to the STANDARD page, NOT overriden
            result.getParameters().put('nooverride','1');   
        } else if (canUseSkuid) {
            // Send the user to the Skuid UI page
            PageReference skuidMain = new PageReference('/apex/skuid__UI');
            if (result != null) {
                skuidMain.getParameters().putAll(result.getParameters());   
            } else {
                skuidMain.getParameters().putAll(ApexPages.currentPage().getParameters());  
            }
            result = skuidMain;
        }
        return result;  
    }
    
    public Redirects() {}
    public Redirects(ApexPages.StandardController ctl) {this.stdCtl = ctl;}
    public Redirects(ApexPages.StandardSetController ctl) {this.setCtl = ctl;}
    
    ///////////// 
    // UNIT TESTS
    /////////////
    
    // Test the controller when the user CAN use Skuid,
    // in which case they should NOT be redirected
    private static testMethod void TestCanUseSkuid() {
        // Load up our normal, no override controller
        Redirects ctl = new Redirects();
        
        // Run the getter for can use Skuid
        boolean canUseSkuid = ctl.canUseSkuid;
        
        // Manually set can use Skuid to TRUE
        ctl.canUseSkuid = true;
        
        // If we CAN Use Skuid, 
        // then our returned redirect should be to the Skuid UI page
        PageReference uiPage = new PageReference('/apex/skuid__UI');
        System.assert(ctl.getRedirect().getURL().contains(uiPage.getURL()));
    }
    
    // Test Redirects to standard controller actions when the user CANNOT use Skuid
    private static testMethod void TestStandardControllerActions() {
        // Create a test Account
        Account a = new Account(Name='Unit_Test_Account');
        insert a;
        
        //
        // VIEW ACTION
        //
        
        // Load up our controller
        ApexPages.StandardController stdctl = new ApexPages.StandardController(a); 
        Redirects ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        PageReference result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should be added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        // We should be sent to the standard VIEW page for the record
        System.assert(result.getUrl().startsWith('/'+String.valueOf(a.Id).substring(0,15)));
        
        //
        // EDIT ACTION
        //
        
        // Load up a page reference so that we can pass in some params
        PageReference pgRef = new PageReference('/'+a.Id);
        pgRef.getParameters().put('retURL','/'+a.Id);
        Test.setCurrentPage(pgRef);
        
        // Load up our controller
        stdctl = new ApexPages.StandardController(a); 
        ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should have been added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        // We should be sent to the standard EDIT page for the record
        System.assert(result.getUrl().startsWith('/'+String.valueOf(a.Id).substring(0,15)));
        System.assert(result.getUrl().contains('/e'));
        
        //
        // CLONE ACTION
        //
        
        // Load up a page reference so that we can pass in some params
        DescribeSObjectResult accountObj = Account.SObjectType.getDescribe();
        pgRef = new PageReference('/'+accountObj.getKeyPrefix()+'/e');
        pgRef.getParameters().put('id',a.Id);
        pgRef.getParameters().put('clone','1');
        Test.setCurrentPage(pgRef);
        
        // Load up our controller
        stdctl = new ApexPages.StandardController(a); 
        ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should have been added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        // We should be sent to the standard CLONE page for the record
        System.assert(result.getUrl().startsWith('/'+accountObj.getKeyPrefix()+'/e'));
        System.assertEquals(result.getParameters().get('clone'),'1');
        System.assert(result.getParameters().get('id').startsWith(String.valueOf(a.Id).substring(0,15)));
        
        //
        // NEW ACTION
        //
        
        // Load up a page reference so that we can pass in some params
        pgRef = new PageReference('/'+accountObj.getKeyPrefix()+'/e');
        pgRef.getParameters().put('RecordType','asdkfjkasdf');
        pgRef.getParameters().put('ent','Account');
        Test.setCurrentPage(pgRef);
        
        // Load up our controller
        stdctl = new ApexPages.StandardController(new Account()); 
        ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should have been added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        // We should be sent to the standard NEW page for the record
        System.assert(result.getUrl().startsWith('/'+accountObj.getKeyPrefix()+'/e'));
        System.assertEquals('asdkfjkasdf',result.getParameters().get('RecordType'));
        System.assertEquals('Account',result.getParameters().get('ent'));
        
        //
        // DELETE ACTION
        //
        
        // Load up a page reference so that we can pass in some params
        pgRef = new PageReference('/');
        pgRef.getParameters().put('delID',String.valueOf(a.Id).substring(0,15));
        Test.setCurrentPage(pgRef);
        
        // Load up our controller
        stdctl = new ApexPages.StandardController(a); 
        ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should have been added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        
    }
    
    // Test Redirects to Standard SET controller actions when the user CANNOT use Skuid
    private static testMethod void TestStandardSetControllerActions() {
        // Create a test Account
        Account a = new Account(Name='Unit_Test_Account');
        insert a;
        List<Account> accs = new List<Account>{a};
        String keyPrefix = Account.SObjectType.getDescribe().getKeyPrefix();
        //
        // TAB ACTION
        //
        
        // Load up a set controller
        ApexPages.StandardSetController stdctl = new ApexPages.StandardSetController(accs); 
        Redirects ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        PageReference result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should be added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        // We should be sent to the standard TAB page for the record
        System.assert(result.getUrl().startsWith('/'+keyPrefix+'/o'));
        
        //
        // LIST ACTION
        //
        
        // Load up a page reference so that we can pass in some params
        PageReference pgRef = new PageReference('/'+keyPrefix);
        // Get a filter id to use
        List<SelectOption> filters = stdctl.getListViewOptions();
        String filterId15 = filters[0].getValue().substring(0,15);
        pgRef.getParameters().put('fcf',filterId15);
        Test.setCurrentPage(pgRef);
        
        // Load up a set controller
        stdctl = new ApexPages.StandardSetController(accs); 
        ctl = new Redirects(stdctl);
        // Simulate not having permission to use Skuid
        ctl.canUseSkuid = false;
        // Simulate running the redirect page action method
        result = ctl.redirect();
        System.assertNotEquals(null,result);
        // The nooverride param should be added
        System.assertEquals(result.getParameters().get('nooverride'),'1');
        // We should be sent to the standard LIST page for the record
        System.assert(result.getUrl().startsWith('/'+keyPrefix));
        System.assertEquals(filterId15,result.getParameters().get('fcf'));
        
    }
}

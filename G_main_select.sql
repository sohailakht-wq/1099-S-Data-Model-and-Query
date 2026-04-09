SELECT 
       :P_FORM_STATUS as FORM_STATUS,
       vendor_name,
       tax_reporting_name,
       vendor_id,
       vendor_line,
       vendor_city,
       vendor_state,
       vendor_zip,
       current_error_text,
       num_1099,
        gov1,
		  gov4,
		gov6,
		gov7, 	
       C_RECIPIENT_NAME, 
       C_VENDOR_CITY_STATE_ZIP, 
       C_total,
       reporting_year,
	   Legal_Description,
	   Date_of_Closing,
	   T_GOV7_AMT	   
FROM(
         SELECT pvw.vendor_name vendor_name,
	        pvw.tax_reporting_name tax_reporting_name,
	        TD.vendor_id vendor_id,
	        substr(pvw.address_line1 || ' ' || pvw.address_line2 || ' ' ||
	               pvw.address_line3,
	               1,
	               33) vendor_line,
	        pvw.city vendor_city,
	        pvw.state vendor_state,
	        pvw.zip vendor_zip,
	        AP_APXT7F99G_XMLP_PKG.C_ERROR_DUMMYFORMULA(decode(pvw.address_line1, '', 'No Address Line 1. ') ||
	        decode(substr(pvw.organization_type_lookup_code, 1, 7),
	               'FOREIGN',
	               decode(pvw.country, '', 'No country. '),
	               nvl(decode(length(replace(replace(nvl(pvw.national_identifier,
	                                                     nvl(null/*P.individual_1099*/,PII.income_tax_id)),
	                                                 '-',
	                                                 ''),
	                                         ' ',
	                                         '')),
	                          0,
	                          '',
	                          9,
	                          '',
	                          'TIN not 9 digits. '),
	                   decode(ltrim(translate(nvl(pvw.national_identifier,
	                                              nvl(null/*P.individual_1099*/,PII.income_tax_id)),
	                                          '1234567890- ',
	                                          ' ')),
	                          '',
	                          '',
	                          'TIN contains non-numeric digit(s). ')) ||
	               decode(pvw.city, '', 'No city. ') ||
	               decode(nvl(pvw.province, pvw.state), '', 'No state. ') ||
	               decode(replace(replace(pvw.zip, '-', ''), ' ', ''),
	                      '',
	                      'No postal code. ')), pvw.vendor_name) current_error_text,
	        decode(replace(replace(nvl(pvw.national_identifier,
	                                   nvl(null/*P.individual_1099*/,PII.income_tax_id)),
	                               '-',
	                               ''),
	                       ' ',
	                       ''),
	               '000000000',
	               '',
	               nvl(pvw.national_identifier,
	                   nvl(null/*P.individual_1099*/,PII.income_tax_id))) num_1099,
	        sum(TD.GOV1) gov1,
			  SUM(TD.GOV4) gov4,
	        sum(TD.GOV6) + sum(TD.GOV6A) gov6,
	        sum(TD.GOV7) gov7,    
	 	AP_APXT7F99_XMLP_PKG.c_recipient_nameformula(Pvw.tax_reporting_name, pvw.vendor_name) C_RECIPIENT_NAME, 
	 	AP_APXT7F99G_XMLP_PKG.c_vendor_city_state_zipformula(pvw.city, pvw.state, pvw.zip) C_VENDOR_CITY_STATE_ZIP, 
      AP_APXT7F99G_XMLP_PKG.c_totalformula(sum ( GOV1 ), SUM(gov4), sum(GOV6),sum ( GOV6A ), sum ( GOV7 ))  C_total,
                to_char(:P_START_YEAR_DATE, 'YYYY') reporting_year,
	    INVPAY.Legal_Description,
		INVPAY.Date_of_Closing,
		T_GOV7_AMT	
	  FROM ap_1099g_data_all TD,
	       POZ_SUPPLIERS_PII PII,       
	        (SELECT P.vendor_id VENDOR_ID,
	        tca_party.party_name VENDOR_NAME,
	        P.tax_reporting_name TAX_REPORTING_NAME,
	        p.organization_type_lookup_code ORGANIZATION_TYPE_LOOKUP_CODE,
	        NULL NATIONAL_IDENTIFIER,
	        pvs.province PROVINCE,
	        pvs.address_line1 ADDRESS_LINE1,
	        pvs.address_line2 ADDRESS_LINE2,
	        pvs.address_line3 ADDRESS_LINE3,
	        pvs.state STATE,
	        pvs.city CITY,
	        pvs.zip ZIP,
	        pvs.COUNTRY COUNTRY
	 FROM poz_suppliers P,
	      HZ_PARTIES tca_party,
	      poz_supplier_sites_v pvs
	  WHERE tca_party.party_id = 	P.party_id
	    AND pvs.vendor_id = P.vendor_id
	  and pvs.vendor_site_id = (SELECT min(vendor_site_id) 
                              FROM POZ_SITE_ASSIGNMENTS_ALL_M PVSA 
							 WHERE PVSA.VENDOR_SITE_ID in (select x.vendor_site_id 
							                                 from poz_supplier_sites_v x 
															where x.vendor_id = p.vendor_id 
															  and (NVL(x.tax_reporting_site_flag,'N') = 'Y' or
					(x.vendor_site_code =
	        (select min(vendor_site_code)
	             from fusion.poz_supplier_sites_v pvs2
	            where pvs2.vendor_id = x.vendor_id
	              and nvl(inactive_date, sysdate + 9000) =
	                  (select max(decode(inactive_date,
	                                     '',
	                                     sysdate + 9000,
	                                     inactive_date))
	                     from fusion.poz_supplier_sites_v pvs3
	                    where pvs3.vendor_id = x.vendor_id)) 
	          AND not exists
	         (SELECT 'A tax reporting site exists for this vendor'
	             FROM fusion.poz_supplier_sites_v pvs4
	            WHERE NVL(pvs4.tax_reporting_site_flag,'N') = 'Y'
	              AND pvs4.vendor_id = x.vendor_id))
						))
  AND PVSA.BU_ID in (select client_bu_org_id from FUN_BU_SERVICE_PROVIDERS where provider_bu_org_id=:P_BUSINESS_UNIT
 and downstream_function_id in (select business_function_id from FUN_BUSINESS_FUNCTIONS_B where business_function_code = 'PAYABLES_PAYMENT_BF')))	    
            AND nvl(p.vendor_type_lookup_code, 'DUMMY') <> 'EMPLOYEE' /*Bug 9247826*/
	    AND (NVL(pvs.tax_reporting_site_flag,'N') = 'Y' OR
	        (pvs.vendor_site_code =
	        (select min(vendor_site_code)
	             from poz_supplier_sites_v pvs2
	            where pvs2.vendor_id = pvs.vendor_id
	              and nvl(inactive_date, sysdate + 9000) =
	                  (select max(decode(inactive_date,
	                                     '',
	                                     sysdate + 9000,
	                                     inactive_date))
	                     from poz_supplier_sites_v pvs3
	                    where pvs3.vendor_id = pvs.vendor_id)) 
	          AND not exists
	         (SELECT 'A tax reporting site exists for this vendor'
	             FROM poz_supplier_sites_v pvs4
	            WHERE NVL(pvs4.tax_reporting_site_flag,'N') = 'Y'
	              AND pvs4.vendor_id = pvs.vendor_id))) 
				) pvw,
		 (select 
				org_id
				,vendor_name
				,segment1
				,business_unit
				,vendor_id
				,vendor_site_id
				,Legal_Description
				,Date_of_Closing
				,TYPE_1099
				,sum(D_GOV7_AMT) T_GOV7_AMT
			FROM
				(
				SELECT apa.org_id
				--	,a.invoice_num
					,pv.vendor_name
					,pv.segment1
				--	,TO_CHAR(A.INVOICE_DATE, 'dd/MM/yyyy') INVOICE_DATE
				--	,TO_CHAR(APA.ACCOUNTING_DATE, 'dd/MM/yyyy') ACCOUNTING_DATE
					,bu.bu_name business_unit
					,a.vendor_id
					,a.vendor_site_id
					--,a.invoice_amount INV_AMOUNT
					--,apa.AMOUNT payment_amount
					--,apa.invoice_currency_code INV_CURR_CODE
					--,apa.Invoice_ID
					,CASE WHEN a.ATTRIBUTE_CATEGORY = '1099-S' THEN
						a.ATTRIBUTE1 
					 ELSE ''
					 END AS Legal_Description
					,CASE WHEN a.ATTRIBUTE_CATEGORY = '1099-S' THEN
						to_char(a.ATTRIBUTE_DATE1,'DD/MM/YYYY')
					 ELSE ''
					 END as Date_of_Closing
					--,ida.INCOME_TAX_REGION
					,ida.TOTAL_DIST_AMOUNT D_GOV7_AMT
					,ida.TYPE_1099
				FROM ap_invoices_all a
					,ap_invoice_distributions_all ida
					,ap_invoice_payments_all apa
					,poz_suppliers_v pv
					,poz_supplier_sites_v pvs
					,ap_checks_all ac
					,IBY_PAYMENTS_ALL pa
					,fun_all_business_units_v bu
				WHERE apa.invoice_id = a.invoice_id
					AND a.vendor_id = pv.vendor_id
					AND a.vendor_site_id = pvs.vendor_site_id
					AND pv.vendor_id = pvs.vendor_id
					AND ac.CHECK_ID = apa.CHECK_ID
					AND pa.payment_id = ac.payment_id
					AND A.INVOICE_ID = IDA.INVOICE_ID
					--AND pv.vendor_name = 'MITCHELL INSTRUMENT COMPANY'
					AND a.org_id = bu.bu_id
					and ida.TYPE_1099 = 'GOV 7'   -- Only "GOV 7" 
					AND apa.ACCOUNTING_DATE >= :P_START_YEAR_DATE
					AND apa.ACCOUNTING_DATE <= :P_END_YEAR_DATE
				)
			group by 
			org_id
			,vendor_name
			,segment1
			,business_unit
			,vendor_id
			,vendor_site_id
			,Legal_Description
			,Date_of_Closing
			,TYPE_1099
		) INVPAY 		
	 where pvw.vendor_id = TD.vendor_id  
	   AND pvw.vendor_id = INVPAY.vendor_id
	   AND pvw.vendor_id = PII.vendor_id (+)
       AND TD.org_id = :P_BUSINESS_UNIT
	   AND TD.org_id = INVPAY.org_id	   
	  GROUP BY pvw.vendor_name,
	           TD.vendor_id,
	           nvl(pvw.national_identifier, nvl(null/*P.individual_1099*/,PII.income_tax_id)),
	           pvw.tax_reporting_name,
	           pvw.organization_type_lookup_code,
	           pvw.country,
	           pvw.address_line1,
	           pvw.address_line2,
	           pvw.address_line3,
	           pvw.city,
	           pvw.province,
	           pvw.state,
	           pvw.zip,
			   INVPAY.Legal_Description,
		       INVPAY.Date_of_Closing,
			   T_GOV7_AMT
			   ) WHERE ((C_total) > 0 OR to_char(:P_START_YEAR_DATE, 'YYYY')<2020) /* Bug 30962385 */
	 ORDER BY (decode(:P_ORDER_BY,
	                   'STATE CODE',
	                   vendor_state,
	                   'REPORTING NAME',
	                   nvl(tax_reporting_name, vendor_name),
                  vendor_state))

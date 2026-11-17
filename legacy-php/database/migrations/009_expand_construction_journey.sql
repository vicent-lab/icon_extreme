-- Expand only built-in journey copy; preserve administrator-written descriptions.
UPDATE company_settings
SET setting_value = 'Every project starts with a conversation about what you want to build, improve or repair. We discuss how the space will be used, your priorities, preferred timeline and budget range, then record the key requirements and questions to explore. This gives both sides a clear starting brief before site visits, designs or estimates are prepared.'
WHERE setting_key = 'company_process_1_description'
  AND setting_value = 'We listen to your goals, budget priorities, intended use and preferred timeline.';

UPDATE company_settings
SET setting_value = 'We review the site and the conditions that may affect the work, including access, existing structures, ground levels, drainage, utilities and nearby activity. We discuss any visible constraints with you and identify information that may need specialist investigation. Findings help shape a practical scope; technical surveys or engineering checks are arranged where the project requires them.'
WHERE setting_key = 'company_process_2_description'
  AND setting_value = 'We discuss the site, access, ground conditions, utilities and practical constraints.';

UPDATE company_settings
SET setting_value = 'Planning & Design'
WHERE setting_key = 'company_process_3_title'
  AND setting_value = 'Planning';

UPDATE company_settings
SET setting_value = 'Using the agreed brief and site information, the project team develops or reviews the drawings, specifications and sequence of work needed to define the project. We discuss material options, finish expectations, approvals and any decisions still required, so changes can be considered before construction. Design work, permits and statutory approvals are confirmed with the appropriate qualified professionals and authorities.'
WHERE setting_key = 'company_process_3_description'
  AND setting_value = 'We clarify the brief, drawings, material options and approvals needed for your project.';

UPDATE company_settings
SET setting_value = 'Once the scope is clear enough to price, we prepare an itemised estimate showing the proposed work, materials, labour and other agreed cost items in Ugandan shillings. We explain assumptions, exclusions, allowances and any items that could change if site conditions or selections differ. You can review the estimate, ask questions and agree on revisions before deciding whether to proceed.'
WHERE setting_key = 'company_process_4_description'
  AND setting_value = 'We prepare a scope-based estimate in Ugandan shillings for review before work is agreed.';

UPDATE company_settings AS title
JOIN company_settings AS description
  ON description.setting_key = 'company_process_5_description'
SET title.setting_value = 'Contract & Mobilization'
WHERE title.setting_key = 'company_process_5_title'
  AND title.setting_value = 'Construction'
  AND description.setting_value = 'Work progresses in planned stages with regular coordination and updates.';

UPDATE company_settings
SET setting_value = 'Before work begins, the parties review and agree the scope, drawings, price, payment stages, schedule, responsibilities and process for handling changes. After the agreement is documented, the team plans site access, safety arrangements, material deliveries, staffing and the first work sequence. Mobilization proceeds when required approvals, access and agreed start conditions are in place.'
WHERE setting_key = 'company_process_5_description'
  AND setting_value IN (
      'Work progresses in planned stages with regular coordination and updates.',
      'Once terms are agreed, we document responsibilities, schedule and site mobilization.'
  );

UPDATE company_settings AS title
JOIN company_settings AS description
  ON description.setting_key = 'company_process_6_description'
SET title.setting_value = 'Construction'
WHERE title.setting_key = 'company_process_6_title'
  AND title.setting_value = 'Quality Inspection'
  AND description.setting_value = 'We review completed work against the agreed scope and address outstanding items.';

UPDATE company_settings
SET setting_value = 'The agreed work is carried out in planned stages, with coordination between the site team, client and relevant suppliers or specialists. Progress, upcoming decisions and any issue affecting the scope or schedule are discussed as the work advances. Materials and workmanship are checked at suitable stages, and changes are reviewed and agreed before additional work is undertaken.'
WHERE setting_key = 'company_process_6_description'
  AND setting_value IN (
      'Work progresses in planned stages with regular coordination and updates.',
      'We review completed work against the agreed scope and address outstanding items.'
  );

UPDATE company_settings AS title
JOIN company_settings AS description
  ON description.setting_key = 'company_process_7_description'
SET title.setting_value = 'Quality Inspection'
WHERE title.setting_key = 'company_process_7_title'
  AND title.setting_value = 'Handover'
  AND description.setting_value = 'We walk through the finished work, share relevant handover information and agree on close-out.';

UPDATE company_settings
SET setting_value = 'As work reaches its agreed milestones and completion, the team checks finished items against the drawings, specifications and scope. We walk through the relevant areas with you, record outstanding or corrective items and agree how they will be addressed. Inspections required from engineers, consultants or authorities are coordinated separately where applicable to the project.'
WHERE setting_key = 'company_process_7_description'
  AND setting_value IN (
      'We review completed work against the agreed scope and address outstanding items.',
      'We walk through the finished work, share relevant handover information and agree on close-out.'
  );

UPDATE company_settings
SET setting_value = 'At handover, we review the completed work with you, confirm the status of agreed outstanding items and share relevant keys, operating guidance, warranties or product information available for the project. We clarify any agreed follow-up arrangements and record completion of the handover. The aim is to leave you with a clear understanding of the finished space and its documentation.'
WHERE setting_key = 'company_process_8_description'
  AND setting_value = 'We walk through the finished work, share relevant handover information and agree on close-out.';

INSERT IGNORE INTO company_settings (setting_key, setting_value, is_public) VALUES
    ('company_process_8_title', 'Handover', 1),
    ('company_process_8_description', 'At handover, we review the completed work with you, confirm the status of agreed outstanding items and share relevant keys, operating guidance, warranties or product information available for the project. We clarify any agreed follow-up arrangements and record completion of the handover. The aim is to leave you with a clear understanding of the finished space and its documentation.', 1),
    ('company_process_8_image', 'images/site/process-handover.webp', 1);

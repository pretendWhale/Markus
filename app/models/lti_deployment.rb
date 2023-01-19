class LtiDeployment < ApplicationRecord
  belongs_to :course, optional: true
  belongs_to :lti_client
  has_many :lti_services, dependent: :destroy
  has_many :lti_line_items, dependent: :destroy
  validates :external_deployment_id, uniqueness: { scope: :lti_client }
  # See LTI documentation for full lists of scopes/claims/roles
  # https://www.imsglobal.org/spec/lti/v1p3
  LTI_SCOPES = { names_role: 'https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly',
                 ags_lineitem: 'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem',
                 score: 'https://purl.imsglobal.org/spec/lti-ags/scope/score',
                 results: 'https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly' }.freeze
  LTI_CLAIMS = { context: 'https://purl.imsglobal.org/spec/lti/claim/context',
                 custom: 'https://purl.imsglobal.org/spec/lti/claim/custom',
                 names_role: 'https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice',
                 ags_lineitem: 'https://purl.imsglobal.org/spec/lti-ags/claim/endpoint',
                 deployment_id: 'https://purl.imsglobal.org/spec/lti/claim/deployment_id',
                 user_launch_data: 'https://purl.imsglobal.org/spec/lti/claim/lti1p1' }.freeze
  LTI_ROLES = { learner: 'http://purl.imsglobal.org/vocab/lis/v2/membership#Learner',
                test_user: 'http://purl.imsglobal.org/vocab/lti/system/person#TestUser' }.freeze

  # Gets a list of all users in the LMS course associated with this deployment
  # with the learner role and creates roles and LTI IDs for each user.
  class LimitExceededException < StandardError; end
  class UnauthorizedException < StandardError; end

  class CannotSyncGradesException < StandardError; end

  # Creates or updates an assignment in the LMS gradebook for a given assessment.
  def create_or_update_lti_assessment(assessment)
    payload = {
      label: assessment.description,
      resourceId: assessment.short_identifier,
      scoreMaximum: assessment.max_mark.to_f
    }
    auth_data = lti_client.get_oauth_token([LTI_SCOPES[:ags_lineitem]])
    lineitem_service = self.lti_services.find_by!(service_type: 'agslineitem')
    lineitem_uri = URI(lineitem_service.url)
    line_item = self.lti_line_items.find_or_initialize_by(assessment: assessment)
    if line_item.lti_line_item_id?
      req = Net::HTTP::Put.new(line_item.lti_line_item_id)
    else
      req = Net::HTTP::Post.new(lineitem_uri)
    end
    req.set_form_data(payload)
    res = send_lti_request!(req, lineitem_uri, auth_data, [LTI_SCOPES[:ags_lineitem]])
    line_item_data = JSON.parse(res.body)
    line_item.update!(lti_line_item_id: line_item_data['id'])
  end

  def send_lti_request(req, uri, auth_data)
    req['Authorization'] = "#{auth_data['token_type']} #{auth_data['access_token']}"
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(req)
    end
  end

  def send_lti_request!(req, uri, auth_data, scopes)
    conn_attempts = 0
    token_resets = 0
    res = send_lti_request(req, uri, auth_data)
    unless res.is_a?(Net::HTTPSuccess)
      raise LimitExceededException if res.code == '429'
      raise UnauthorizedException if res.code == '401'
      raise StandardError, " uri: #{uri} body: #{JSON.parse(res.body)}"
    end
    res
  rescue LimitExceededException
    conn_attempts += 1
    raise CannotSyncGradesException if conn_attempts >= 5
    sleep(10)
    retry
  rescue UnauthorizedException
    token_resets += 1
    raise CannotSyncGradesException if token_resets >= 5
    lti_client.get_oauth_token(scopes)
    retry
  end
end

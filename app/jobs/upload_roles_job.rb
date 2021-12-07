# upload users job
class UploadRolesJob < ApplicationJob
  def perform(role_class, course, data, encoding)
    progress.total = data.lines.count
    if role_class == Student
      @sections = course.sections.pluck(:name, :id).to_h
      @section_index = Student::CSV_ORDER.index(:section_name)
    end
    user_name_index = Student::CSV_ORDER.index(:user_name) || 0
    role_class.transaction do
      MarkusCsv.parse(data, encoding: encoding, skip_blanks: true, row_sep: :auto) do |row|
        user_name = row[user_name_index]&.strip
        next if user_name.blank?
        human = Human.find_by_user_name(user_name)
        raise I18n.t('users.not_found', user_names: user_name) if human.nil?
        role = role_class.new(human: human, course: course, section_id: find_section_id(row))
        raise "#{user_name}: #{role.errors.full_messages.join('; ')}" unless role.save
        progress.increment
      end
    end
  end

  def find_section_id(row)
    return nil if @section_index.nil?
    section_name = row[@section_index]&.strip
    return nil if section_name.blank?
    section_id = @sections[row[@section_index]&.strip]
    raise I18n.t('sections.not_found', name: row[@section_index]&.strip) if section_id.nil?
    section_id
  end
end
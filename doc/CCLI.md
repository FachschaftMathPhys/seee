# API

The api is mounted in namespace /api/
Following ressources are aviable:

| Ressource |  description | attributes | relationships |
| --------- |  ----------- | --------   | ------------- |
| c_pic    |   course pic |  step, text, source, basename   | course_prof, course, term              |
| course_prof | The relation between a course and a prof |  | returned_sheets , course, prof, form, term, c_pics |
| course | A course | title, students, evaluator, description, summary, fscontact, language, note, mails_sent | form, term, faculty, course_profs, profs, c_pics, tutors |
| faculty | A faculty | longname, shortname, critical | courses, course_profs |
| form | A form | name, critical ,content, languages |term |
| pic | A pic of | basename, source, text, step, for | tutor, course, term |
|prof |  a professor |firstname, surname, email, gender, gender_symbol | course_profs, courses |
| term |  a term | firstday, lastday, title, critical, longtitle | forms, courses, course_profs, tutors, faculties |
| tutor | tutor | abbr_name, comment | course, pics, form, faculty, term |

## Result uploading

For Uploading

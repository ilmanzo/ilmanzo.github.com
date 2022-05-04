<!DOCTYPE html>
<html>
<head><title>my todo list</title></head>
<body>
<h1>my TODO list</h1>
{{ if .DisplayTodos }}
<ul>
{{ range $index,$item := .Todos }}
<li> {{ $index }} {{ $item }} </li>
{{ end }}
</ul>
{{ end }}
<form action="/todoapp" method="post">
  <input type="text" name="entry" size="25">
  <input type="submit" name="submit" value="New TODO">
</form>
</body>
</html>


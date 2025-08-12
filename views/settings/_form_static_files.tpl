<p><b>Static Files</b></p>
<div id="static-files">
  <form method="post" action="/settings/upload" enctype="multipart/form-data">
    <label for="file">Upload File</label>
    <input type="file" name="file" id="file" />
    <input type="submit" value="Upload" />
  </form>

  <table>
    % for file in files:
    <tr>
      <td>
        <form method="post" action="/settings" style="display:inline;">
          <input type="hidden" name="_method" value="DELETE">
          <input type="hidden" name="filename" value="{{file}}">
          <input type="submit" value="删除" class="btn-danger" 
                 onclick="return confirm('确认删除该文件？')" />
        </form>
      </td>
      <td><a href="/{{file}}">{{file}}</a></td>
    </tr>
    % end
  </table>
</div>

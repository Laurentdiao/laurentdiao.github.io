(() => {
  const owner = 'Laurentdiao';
  const repo = 'laurentdiao.github.io';
  const branch = 'main';
  const apiBase = `https://api.github.com/repos/${owner}/${repo}/contents`;
  const tokenKey = 'winnie_blog_admin_token';
  const defaultTags = ['随笔', '技术', '生活', '读书笔记', '朋友圈', '日常', '其他'];
  const localTagsKey = 'winnie_blog_admin_tags';
  const tagsConfigPath = 'source/admin/tags.json';
  const requestTimeoutMs = 15000;

  const state = {
    token: localStorage.getItem(tokenKey) || '',
    tags: loadLocalTags(),
    tagsSha: null,
    posts: [],
    selectedPost: null,
    about: null,
    currentView: 'posts'
  };

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  const elements = {
    viewTitle: $('#view-title'),
    notice: $('#notice'),
    busy: $('#busy'),
    syncLabel: $('#sync-label'),
    setupView: $('#setup-view'),
    postsView: $('#posts-view'),
    aboutView: $('#about-view'),
    settingsView: $('#settings-view'),
    postsList: $('#posts-list'),
    postCount: $('#post-count'),
    postForm: $('#post-form'),
    postMode: $('#post-mode'),
    postOriginalFilename: $('#post-original-filename'),
    postSha: $('#post-sha'),
    postEditorTitle: $('#post-editor-title'),
    postTitle: $('#post-title-input'),
    postContent: $('#post-content-input'),
    deletePost: $('#delete-post-btn'),
    savePost: $('#save-post-btn'),
    tagsGrid: $('#tags-grid'),
    tagInput: $('#tag-input'),
    addTag: $('#add-tag-btn'),
    imageInput: $('#image-input'),
    aboutForm: $('#about-form'),
    aboutSha: $('#about-sha'),
    aboutTitle: $('#about-title-input'),
    aboutContent: $('#about-content-input'),
    setupToken: $('#setup-token'),
    settingsToken: $('#settings-token')
  };

  document.addEventListener('DOMContentLoaded', init);

  function init() {
    const params = new URLSearchParams(window.location.search);
    if (params.has('reset')) {
      state.token = '';
      localStorage.removeItem(tokenKey);
      clearAdminCaches();
    }
    renderTags();
    bindEvents();
    renderTokenState();
    setView(state.token ? 'posts' : 'settings');
    if (state.token) {
      showNotice('已保存 token。点右上角刷新开始同步。', false);
    }
    clearAdminCaches();
  }

  function bindEvents() {
    $$('.nav-btn').forEach((button) => {
      button.addEventListener('click', () => setView(button.dataset.view));
    });

    $('#refresh-btn').addEventListener('click', syncAll);
    $('#new-post-btn').addEventListener('click', startNewPost);
    $('#mobile-new-post-btn').addEventListener('click', startNewPost);
    $('#reset-post-btn').addEventListener('click', startNewPost);
    $('#open-site-btn').addEventListener('click', () => window.open('https://laurentdiao.github.io', '_blank', 'noreferrer'));
    $('#image-btn').addEventListener('click', () => elements.imageInput.click());
    elements.imageInput.addEventListener('change', handleImageSelection);
    elements.addTag.addEventListener('click', addTagFromInput);
    elements.tagInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        addTagFromInput();
      }
    });
    elements.postForm.addEventListener('submit', savePost);
    elements.deletePost.addEventListener('click', deleteSelectedPost);
    elements.aboutForm.addEventListener('submit', saveAbout);
    $('#setup-save-btn').addEventListener('click', () => saveToken(elements.setupToken.value));
    $('#settings-save-btn').addEventListener('click', () => saveToken(elements.settingsToken.value));
    $('#settings-clear-btn').addEventListener('click', clearToken);
  }

  function renderTags(extraTags = []) {
    const visibleTags = mergeTags([...state.tags, ...extraTags, ...(state.selectedPost?.tags || [])]);
    elements.tagsGrid.innerHTML = visibleTags.map((tag) => {
      const canRemove = state.tags.includes(tag);
      return `
      <span class="tag-chip-wrap ${canRemove ? '' : 'is-post-only'}">
        <label class="tag-chip">
          <input type="checkbox" name="tag" value="${escapeAttr(tag)}">
          <span>${escapeHtml(tag)}</span>
        </label>
        ${canRemove ? `<button class="tag-remove-btn" type="button" data-tag="${escapeAttr(tag)}" aria-label="删除标签 ${escapeAttr(tag)}">×</button>` : ''}
      </span>
    `;
    }).join('');

    $$('.tag-remove-btn').forEach((button) => {
      button.addEventListener('click', () => removeTag(button.dataset.tag));
    });
  }

  function renderTokenState() {
    elements.setupToken.value = state.token;
    elements.settingsToken.value = state.token;
    if (!state.token) {
      elements.syncLabel.textContent = '未连接 GitHub';
    }
  }

  function setView(view) {
    state.currentView = view;
    $$('.nav-btn').forEach((button) => button.classList.toggle('is-active', button.dataset.view === view));

    const configured = Boolean(state.token);
    elements.setupView.hidden = configured;
    elements.postsView.hidden = !configured || view !== 'posts';
    elements.aboutView.hidden = !configured || view !== 'about';
    elements.settingsView.hidden = !configured || view !== 'settings';
    $('#refresh-btn').disabled = !configured;
    $('#new-post-btn').disabled = !configured;
    $('#mobile-new-post-btn').disabled = !configured;

    const titles = { posts: '文章', about: 'About Me', settings: '设置' };
    elements.viewTitle.textContent = configured ? titles[view] : '设置';

    if (configured && view === 'about' && !state.about) {
      loadAbout();
    }
  }

  async function syncAll() {
    if (!requireToken()) return;
    await withBusy(async () => {
      await loadTagsConfig();
      await Promise.all([loadPosts(), loadAbout()]);
      elements.syncLabel.textContent = `已同步 ${formatTime(new Date())}`;
      showNotice('同步完成。', false);
    });
  }

  async function loadTagsConfig() {
    try {
      const file = await githubJSON(tagsConfigPath);
      const data = JSON.parse(decodeBase64Text(file.content || ''));
      const nextTags = mergeTags(Array.isArray(data.tags) ? data.tags : defaultTags);
      state.tags = nextTags.length ? nextTags : [...defaultTags];
      state.tagsSha = file.sha;
      saveLocalTags();
      renderTags();
    } catch (error) {
      if (String(error.message || '').includes('GitHub 返回 404')) {
        state.tags = mergeTags(state.tags);
        state.tagsSha = null;
        await saveTagsConfig('Create admin tags');
        return;
      }
      throw error;
    }
  }

  async function loadPosts() {
    const files = await githubJSON('source/_posts');
    const markdownFiles = files.filter((file) => file.name.endsWith('.md'));
    const posts = [];

    for (const file of markdownFiles) {
      const full = await githubJSON(file.path);
      const markdown = decodeBase64Text(full.content || '');
      const parsed = parseMarkdown(markdown);
      const tags = listValue(parsed, 'tags');
      const categories = listValue(parsed, 'categories');
      const title = parsed.frontMatter.title || '';
      posts.push({
        title,
        displayTitle: title || displayTitleFromPost(parsed.body),
        titleless: isTruthy(parsed.frontMatter.titleless) || !title,
        date: parsed.frontMatter.date || '',
        tags,
        categories,
        content: parsed.body,
        filename: file.name,
        path: file.path,
        sha: full.sha
      });
    }

    state.posts = posts.sort((a, b) => String(b.date).localeCompare(String(a.date)));
    renderPosts();
    renderTags();
    if (!state.selectedPost) startNewPost();
  }

  async function loadAbout() {
    const file = await githubJSON('source/about/index.md');
    const parsed = parseMarkdown(decodeBase64Text(file.content || ''));
    state.about = {
      title: parsed.frontMatter.title || '关于',
      date: parsed.frontMatter.date || blogTimestamp(),
      type: parsed.frontMatter.type || 'about',
      content: parsed.body,
      sha: file.sha
    };
    renderAbout();
  }

  function renderPosts() {
    elements.postCount.textContent = `${state.posts.length} 篇`;
    if (state.posts.length === 0) {
      elements.postsList.innerHTML = '<div class="post-item"><h4>还没有文章</h4><p class="post-excerpt">从右侧开始写第一篇。</p></div>';
      return;
    }

    elements.postsList.innerHTML = state.posts.map((post) => `
      <button class="post-item ${state.selectedPost?.filename === post.filename ? 'is-selected' : ''}" type="button" data-filename="${escapeAttr(post.filename)}">
        <h4>${escapeHtml(post.displayTitle)}</h4>
        <div class="post-meta">
          <span>${escapeHtml(String(post.date).slice(0, 10) || '无日期')}</span>
          ${post.categories.slice(0, 1).map((item) => `<span class="pill">${escapeHtml(item)}</span>`).join('')}
          ${post.tags.slice(0, 2).map((item) => `<span class="pill">${escapeHtml(item)}</span>`).join('')}
        </div>
        <p class="post-excerpt">${escapeHtml(excerpt(post.content))}</p>
      </button>
    `).join('');

    $$('.post-item[data-filename]').forEach((button) => {
      button.addEventListener('click', () => {
        const post = state.posts.find((item) => item.filename === button.dataset.filename);
        if (post) editPost(post);
      });
    });
  }

  function startNewPost() {
    state.selectedPost = null;
    elements.postMode.value = 'create';
    elements.postOriginalFilename.value = '';
    elements.postSha.value = '';
    elements.postEditorTitle.textContent = '写文章';
    elements.savePost.textContent = '发布';
    elements.deletePost.hidden = true;
    elements.postTitle.value = '';
    elements.postContent.value = '';
    setCategory('长文');
    renderTags();
    setSelectedTags(['随笔']);
    renderPosts();
    setView('posts');
  }

  function editPost(post) {
    state.selectedPost = post;
    elements.postMode.value = 'edit';
    elements.postOriginalFilename.value = post.filename;
    elements.postSha.value = post.sha;
    elements.postEditorTitle.textContent = '编辑文章';
    elements.savePost.textContent = '保存';
    elements.deletePost.hidden = false;
    elements.postTitle.value = post.title;
    elements.postContent.value = post.content;
    setCategory(post.categories[0] || '长文');
    renderTags(post.tags);
    setSelectedTags(post.tags.length ? post.tags : ['随笔']);
    renderPosts();
    setView('posts');
  }

  function renderAbout() {
    if (!state.about) return;
    elements.aboutSha.value = state.about.sha;
    elements.aboutTitle.value = state.about.title;
    elements.aboutContent.value = state.about.content;
  }

  async function savePost(event) {
    event.preventDefault();
    if (!requireToken()) return;

    const title = elements.postTitle.value.trim();
    const content = elements.postContent.value.trim();
    if (!content) {
      showNotice('正文要填写。朋友圈可以不填标题。', true);
      return;
    }

    const selectedTags = getSelectedTags();
    const category = getSelectedCategory();
    const titleless = !title;
    if (titleless && !selectedTags.includes('朋友圈')) {
      showNotice('只有标签为朋友圈的文章可以不填标题。', true);
      return;
    }
    const filenameBase = title || state.selectedPost?.filename?.replace(/\.md$/i, '') || `moment-${compactTimestamp()}`;
    const filename = `${sanitizeFilename(filenameBase)}.md`;
    const actionTitle = title || displayTitleFromPost(content);
    const path = `source/_posts/${filename}`;
    const markdown = postMarkdown({
      title,
      titleless,
      date: state.selectedPost?.date || blogTimestamp(),
      tags: selectedTags.length ? selectedTags : ['随笔'],
      categories: [category],
      content
    });

    await withBusy(async () => {
      const mode = elements.postMode.value;
      if (mode === 'edit' && elements.postOriginalFilename.value && filename !== elements.postOriginalFilename.value) {
        await putFile(path, markdown, null, `Update ${actionTitle}`);
        await deleteFile(`source/_posts/${elements.postOriginalFilename.value}`, elements.postSha.value, `Rename ${state.selectedPost?.displayTitle || actionTitle}`);
      } else {
        await putFile(path, markdown, mode === 'edit' ? elements.postSha.value : null, mode === 'edit' ? `Update ${actionTitle}` : `Add ${actionTitle}`);
      }

      showNotice('已提交到 GitHub，等待 Actions 更新网页。', false);
      await loadPosts();
      const saved = state.posts.find((post) => post.filename === filename);
      if (saved) editPost(saved);
    });
  }

  async function deleteSelectedPost() {
    if (!state.selectedPost) return;
    const ok = window.confirm(`删除「${state.selectedPost.displayTitle}」？这个操作会直接提交到 GitHub。`);
    if (!ok) return;

    await withBusy(async () => {
      await deleteFile(`source/_posts/${state.selectedPost.filename}`, state.selectedPost.sha, `Delete ${state.selectedPost.displayTitle}`);
      showNotice('文章已删除。', false);
      state.selectedPost = null;
      await loadPosts();
      startNewPost();
    });
  }

  async function saveAbout(event) {
    event.preventDefault();
    if (!requireToken() || !state.about) return;

    const title = elements.aboutTitle.value.trim();
    const content = elements.aboutContent.value.trim();
    if (!title || !content) {
      showNotice('About Me 标题和内容都要填写。', true);
      return;
    }

    const markdown = [
      '---',
      `title: ${title}`,
      `date: ${state.about.date || blogTimestamp()}`,
      `type: ${state.about.type || 'about'}`,
      '---',
      '',
      content,
      ''
    ].join('\n');

    await withBusy(async () => {
      await putFile('source/about/index.md', markdown, state.about.sha, 'Update About Me');
      showNotice('About Me 已提交。', false);
      await loadAbout();
    });
  }

  async function addTagFromInput() {
    const tag = normalizeTag(elements.tagInput.value);
    if (!tag) {
      showNotice('先输入标签名称。', true);
      return;
    }
    const selected = getSelectedTags();
    if (state.tags.includes(tag)) {
      setSelectedTags(mergeTags([...selected, tag]));
      elements.tagInput.value = '';
      showNotice('这个标签已经存在，已帮你选中。', false);
      return;
    }

    state.tags = mergeTags([...state.tags, tag]);
    elements.tagInput.value = '';
    saveLocalTags();
    renderTags([...selected, tag]);
    setSelectedTags(mergeTags([...selected, tag]));

    if (!requireToken()) return;
    await withBusy(async () => {
      await saveTagsConfig(`Add tag ${tag}`);
      showNotice(`已新增标签：${tag}`, false);
    });
  }

  async function removeTag(tag) {
    const normalized = normalizeTag(tag);
    if (!normalized) return;
    const selected = getSelectedTags();
    const used = state.posts.some((post) => post.tags.includes(normalized));
    const message = used
      ? `「${normalized}」已经被文章使用。删除后不会改旧文章，只是不再出现在新文章可选标签里。继续吗？`
      : `删除标签「${normalized}」？`;
    if (!window.confirm(message)) return;

    state.tags = state.tags.filter((item) => item !== normalized);
    if (state.tags.length === 0) state.tags = [...defaultTags];
    saveLocalTags();
    const nextSelected = selected.filter((item) => item !== normalized);
    renderTags(nextSelected);
    setSelectedTags(nextSelected);

    if (!requireToken()) return;
    await withBusy(async () => {
      await saveTagsConfig(`Remove tag ${normalized}`);
      showNotice(`已删除标签：${normalized}`, false);
    });
  }

  async function saveTagsConfig(message) {
    state.tags = mergeTags(state.tags);
    if (state.tags.length === 0) state.tags = [...defaultTags];
    const text = `${JSON.stringify({ tags: state.tags }, null, 2)}\n`;
    const response = await putFile(tagsConfigPath, text, state.tagsSha, message);
    state.tagsSha = response.content?.sha || state.tagsSha;
  }

  async function handleImageSelection(event) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    if (!requireToken()) return;

    await withBusy(async () => {
      const extension = imageExtension(file);
      const path = `source/images/admin_${Date.now()}_${randomSuffix()}.${extension}`;
      const buffer = await file.arrayBuffer();
      await putFileBase64(path, base64FromArrayBuffer(buffer), null, 'Upload image');
      insertAtCursor(elements.postContent, `\n\n![](/images/${path.split('/').pop()})\n`);
      showNotice('图片已上传并插入正文。', false);
    });
  }

  function saveToken(rawToken) {
    const token = rawToken.trim();
    if (!token) {
      showNotice('请先粘贴 GitHub token。', true);
      return;
    }
    state.token = token;
    localStorage.setItem(tokenKey, token);
    renderTokenState();
    setView('posts');
    showNotice('Token 已保存。点右上角刷新开始同步。', false);
  }

  function clearToken() {
    state.token = '';
    localStorage.removeItem(tokenKey);
    clearAdminCaches();
    state.posts = [];
    state.selectedPost = null;
    state.about = null;
    renderTokenState();
    setView('settings');
    showNotice('Token 已清除。', false);
  }

  async function putFile(path, text, sha, message) {
    return putFileBase64(path, base64FromText(text), sha, message);
  }

  async function putFileBase64(path, content, sha, message) {
    const body = { message, content, branch };
    if (sha) body.sha = sha;
    return githubJSON(path, { method: 'PUT', body });
  }

  async function deleteFile(path, sha, message) {
    return githubJSON(path, { method: 'DELETE', body: { message, sha, branch } });
  }

  async function githubJSON(path, options = {}) {
    const method = options.method || 'GET';
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);
    const requestOptions = {
      method,
      signal: controller.signal,
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${state.token}`,
        'X-GitHub-Api-Version': '2022-11-28'
      }
    };

    if (options.body) {
      requestOptions.headers['Content-Type'] = 'application/json';
      requestOptions.body = JSON.stringify(options.body);
    }

    try {
      const response = await fetch(`${apiBase}/${encodePath(path)}`, requestOptions);
      if (!response.ok) {
        let detail = response.statusText;
        try {
          const data = await response.json();
          detail = data.message || detail;
        } catch (_) {}
        if (response.status === 409) {
          detail = '远端刚刚更新，请刷新后重试。';
        }
        if (response.status === 401 || response.status === 403) {
          detail = `${detail}。请检查 token 是否仍有效，并确认 Contents 权限是 Read and write。`;
        }
        throw new Error(`GitHub 返回 ${response.status}: ${detail}`);
      }
      if (response.status === 204) return {};
      return response.json();
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error('GitHub API 请求超时。请检查网络或 token，稍后点刷新重试。');
      }
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  function requireToken() {
    if (state.token) return true;
    setView('settings');
    showNotice('请先保存 GitHub token。', true);
    return false;
  }

  async function withBusy(task) {
    elements.busy.hidden = false;
    clearNotice();
    try {
      await task();
    } catch (error) {
      showNotice(error.message || String(error), true);
    } finally {
      elements.busy.hidden = true;
    }
  }

  function showNotice(message, isError) {
    elements.notice.textContent = message;
    elements.notice.classList.toggle('is-error', Boolean(isError));
    elements.notice.hidden = false;
  }

  function clearNotice() {
    elements.notice.hidden = true;
    elements.notice.textContent = '';
  }

  function clearAdminCaches() {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations()
        .then((registrations) => registrations.forEach((registration) => registration.unregister()))
        .catch(() => {});
    }
    if ('caches' in window) {
      caches.keys()
        .then((keys) => keys.filter((key) => key.startsWith('winnie-blog-admin')).forEach((key) => caches.delete(key)))
        .catch(() => {});
    }
  }

  function parseMarkdown(markdown) {
    const normalized = markdown.replace(/\r\n/g, '\n');
    if (!normalized.startsWith('---\n')) {
      return { frontMatter: {}, lists: {}, body: markdown.trim() };
    }

    const end = normalized.indexOf('\n---', 4);
    if (end === -1) {
      return { frontMatter: {}, lists: {}, body: markdown.trim() };
    }

    const front = normalized.slice(4, end);
    let bodyStart = end + 4;
    if (normalized[bodyStart] === '\n') bodyStart += 1;
    const body = normalized.slice(bodyStart).trim();
    const frontMatter = {};
    const lists = {};
    let activeKey = null;

    front.split('\n').forEach((line) => {
      const trimmed = line.trim();
      if (trimmed.startsWith('- ') && activeKey) {
        const value = trimmed.slice(2).trim();
        if (value) lists[activeKey].push(stripQuotes(value));
        return;
      }
      activeKey = null;
      const colon = trimmed.indexOf(':');
      if (colon === -1) return;
      const key = trimmed.slice(0, colon).trim();
      const value = trimmed.slice(colon + 1).trim();
      if (!value) {
        lists[key] = [];
        activeKey = key;
      } else {
        frontMatter[key] = stripQuotes(value);
      }
    });

    return { frontMatter, lists, body };
  }

  function postMarkdown(post) {
    const lines = ['---', `title: ${yamlString(post.title)}`, `date: ${post.date || blogTimestamp()}`];
    if (post.titleless) {
      lines.push('titleless: true');
    }
    if (post.tags?.length) {
      lines.push('tags:');
      post.tags.forEach((tag) => lines.push(`  - ${yamlString(tag)}`));
    }
    if (post.categories?.length) {
      lines.push('categories:');
      post.categories.forEach((category) => lines.push(`  - ${yamlString(category)}`));
    }
    lines.push('---', '', post.content.trim(), '');
    return lines.join('\n');
  }

  function listValue(parsed, key) {
    if (parsed.lists[key]) return parsed.lists[key];
    if (parsed.frontMatter[key]) return [parsed.frontMatter[key]];
    return [];
  }

  function setCategory(category) {
    $$('input[name="category"]').forEach((input) => {
      input.checked = input.value === category;
    });
  }

  function getSelectedCategory() {
    return $('input[name="category"]:checked')?.value || '长文';
  }

  function setSelectedTags(selected) {
    $$('input[name="tag"]').forEach((input) => {
      input.checked = selected.includes(input.value);
    });
  }

  function getSelectedTags() {
    return $$('input[name="tag"]:checked').map((input) => input.value);
  }

  function insertAtCursor(textarea, text) {
    const start = textarea.selectionStart ?? textarea.value.length;
    const end = textarea.selectionEnd ?? textarea.value.length;
    textarea.value = `${textarea.value.slice(0, start)}${text}${textarea.value.slice(end)}`;
    textarea.focus();
    textarea.selectionStart = textarea.selectionEnd = start + text.length;
  }

  function encodePath(path) {
    return path.split('/').map((part) => encodeURIComponent(part)).join('/');
  }

  function base64FromText(text) {
    return base64FromArrayBuffer(new TextEncoder().encode(text).buffer);
  }

  function base64FromArrayBuffer(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
      binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
    }
    return btoa(binary);
  }

  function decodeBase64Text(value) {
    const binary = atob(String(value).replace(/\n/g, ''));
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    return new TextDecoder().decode(bytes);
  }

  function sanitizeFilename(value) {
    const cleaned = value.replace(/[\\/:*?"<>|]/g, '_').trim();
    return cleaned || `untitled-${Date.now()}`;
  }

  function blogTimestamp() {
    const date = new Date();
    const pad = (number) => String(number).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
  }

  function imageExtension(file) {
    const fromName = file.name.split('.').pop()?.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(fromName)) return fromName;
    const fromType = file.type.split('/').pop()?.toLowerCase();
    if (fromType === 'jpeg') return 'jpg';
    if (['png', 'gif', 'webp'].includes(fromType)) return fromType;
    return 'jpg';
  }

  function randomSuffix() {
    return Math.random().toString(36).slice(2, 8);
  }

  function loadLocalTags() {
    try {
      const parsed = JSON.parse(localStorage.getItem(localTagsKey) || '[]');
      const tags = mergeTags(Array.isArray(parsed) ? parsed : []);
      return tags.length ? tags : [...defaultTags];
    } catch (_) {
      return [...defaultTags];
    }
  }

  function saveLocalTags() {
    localStorage.setItem(localTagsKey, JSON.stringify(state.tags));
  }

  function normalizeTag(value) {
    return String(value || '')
      .replace(/[，,;；]+/g, ' ')
      .replace(/^#+/, '')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 24);
  }

  function mergeTags(values) {
    const tags = [];
    (Array.isArray(values) ? values : []).forEach((value) => {
      const tag = normalizeTag(value);
      if (tag && !tags.includes(tag)) tags.push(tag);
    });
    return tags;
  }

  function displayTitleFromPost(content) {
    const plain = String(content || '')
      .replace(/!\[[^\]]*]\([^)]*\)/g, ' ')
      .replace(/\[([^\]]+)]\([^)]*\)/g, '$1')
      .replace(/<[^>]*>/g, ' ')
      .split('\n')
      .map((line) => line
        .replace(/^#{1,6}\s+/, '')
        .replace(/^>\s*/, '')
        .replace(/^[-*+]\s+/, '')
        .trim())
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (!plain) return '朋友圈动态';
    return plain.length > 28 ? `${plain.slice(0, 28)}...` : plain;
  }

  function isTruthy(value) {
    return value === true || ['true', 'yes', '1'].includes(String(value).toLowerCase());
  }

  function compactTimestamp() {
    const date = new Date();
    const pad = (number) => String(number).padStart(2, '0');
    return [
      date.getFullYear(),
      pad(date.getMonth() + 1),
      pad(date.getDate()),
      pad(date.getHours()),
      pad(date.getMinutes()),
      pad(date.getSeconds())
    ].join('');
  }

  function yamlString(value) {
    return JSON.stringify(String(value || ''));
  }

  function stripQuotes(value) {
    return value.replace(/^['"]|['"]$/g, '');
  }

  function excerpt(value) {
    return String(value || '').replace(/\s+/g, ' ').trim().slice(0, 88) || '无正文预览';
  }

  function formatTime(date) {
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, (char) => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[char]));
  }

  function escapeAttr(value) {
    return escapeHtml(value);
  }
})();
